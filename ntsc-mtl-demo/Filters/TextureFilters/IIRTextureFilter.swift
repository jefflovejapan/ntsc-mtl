//
//  IIRTextureFilter.swift
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-06-04.
//

import Foundation
import Metal

enum IIRTextureFilterError: Error {
    case cantMakeComputeEncoder
    case cantMakeBlitEncoder
    case noNonZeroDenominators
    case cantInstantiateTexture
    case cantMakeFunction(String)
}

class IIRTextureFilter {
    typealias Error = IIRTextureFilterError
    enum InitialCondition {
        case zero
        case firstSample
        case constant([Float])
    }
    
    private let device: MTLDevice
    private let library: MTLLibrary
    private let numerators: [Float]
    private let denominators: [Float]
    private let initialCondition: InitialCondition
    private let scale: Float
    private(set) var zTextures: [MTLTexture] = []
    private var scratchTexture: MTLTexture?
    
    init(device: MTLDevice, library: MTLLibrary, numerators: [Float], denominators: [Float], initialCondition: InitialCondition, scale: Float, delay: UInt) {
        self.device = device
        self.library = library
        let maxLength = max(numerators.count, denominators.count)
        var paddedNumerators: [Float] = Array(repeating: 0, count: maxLength)
        paddedNumerators[0..<numerators.count] = numerators[0...]
        var paddedDenominators: [Float] = Array(repeating: 0, count: maxLength)
        paddedDenominators[0..<denominators.count] = denominators[0...]
        self.numerators = paddedNumerators
        self.denominators = paddedDenominators
        self.initialCondition = initialCondition
        self.scale = scale
    }
    
    private static func texture(width: Int, height: Int, pixelFormat: MTLPixelFormat, device: MTLDevice) -> MTLTexture? {
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: pixelFormat,
            width: width,
            height: height,
            mipmapped: false
        )
        textureDescriptor.usage = [.shaderRead, .shaderWrite, .renderTarget]
        return device.makeTexture(descriptor: textureDescriptor)
    }
    
    private static func textures(width: Int, height: Int, pixelFormat: MTLPixelFormat, device: MTLDevice) -> AnySequence<MTLTexture> {
        return AnySequence {
            return AnyIterator {
                return Self.texture(width: width, height: height, pixelFormat: pixelFormat, device: device)
            }
        }
    }
    
    static func fillTextures(
        outputTexture: MTLTexture,
        initialCondition: InitialCondition,
        initialConditionTexture: MTLTexture,
        textures: [MTLTexture],
        numerators: [Float],
        denominators: [Float],
        library: MTLLibrary,
        device: MTLDevice,
        commandBuffer: MTLCommandBuffer
    ) throws {
        let region = MTLRegionMake2D(0, 0, outputTexture.width, outputTexture.height)
        let bytesPerRow: Int = MemoryLayout<Float>.size * 4 * outputTexture.width
        switch initialCondition {
        case .zero:
            let input: [Float] = [0, 0, 0, 1]   // black/zero
            var yiqa = input
            for tex in textures {
                tex.replace(region: region, mipmapLevel: 0, withBytes: &yiqa, bytesPerRow: bytesPerRow)
            }
            return
        case .firstSample:
            guard let blitEncoder = commandBuffer.makeBlitCommandEncoder() else {
                throw Error.cantMakeBlitEncoder
            }
            blitEncoder.copy(from: outputTexture, to: initialConditionTexture)
            blitEncoder.endEncoding()
        case .constant(let color):
            var yiqa = color
            initialConditionTexture.replace(region: region, mipmapLevel: 0, withBytes: &yiqa, bytesPerRow: bytesPerRow)
        }
        
        guard let firstNonZeroCoeff = denominators.first(where: { !$0.isZero }) else {
            throw Error.noNonZeroDenominators
        }
        
        let normalizedNumerators = numerators.map { num in
            num / firstNonZeroCoeff
        }
        let normalizedDenominators = denominators.map { den in
            den / firstNonZeroCoeff
        }
        
        var bSum: Float = 0
        for i in 1 ..< numerators.count {
            let num = normalizedNumerators[i]
            let den = normalizedDenominators[i]
            bSum += num - (den * normalizedNumerators[0])
        }
        let z0Fill = bSum / normalizedDenominators.reduce(0, +)
        let z0FillValues: [Float] = [z0Fill, z0Fill, z0Fill, 1]
        var z0FillMutable = z0FillValues
        textures[0].replace(region: region, mipmapLevel: 0, withBytes: &z0FillMutable, bytesPerRow: bytesPerRow)
        var aSum: Float = 1
        var cSum: Float = 0
        for i in 1 ..< numerators.count {
            let num = normalizedNumerators[i]
            let den = normalizedDenominators[i]
            aSum += den
            cSum += (num - (den * normalizedNumerators[0]))
            try initialConditionFill(
                textureToFill: textures[i],
                initialConditionTexture: initialConditionTexture,
                aSum: aSum,
                cSum: cSum,
                library: library,
                device: device,
                commandBuffer: commandBuffer
            )
        }
        try finalFill(
            textureToFill: textures[0], 
            initialConditionTexture: initialConditionTexture,
            library: library,
            device: device,
            commandBuffer: commandBuffer
        )
    }
    
    static func initialConditionFill(textureToFill: MTLTexture, initialConditionTexture: MTLTexture, aSum: Float, cSum: Float, library: MTLLibrary, device: MTLDevice, commandBuffer: MTLCommandBuffer) throws {
        let functionName = "iirInitialCondition"
        guard let function = library.makeFunction(name: functionName) else {
            throw Error.cantMakeFunction(functionName)
        }
        guard let commandEncoder = commandBuffer.makeComputeCommandEncoder() else {
            throw Error.cantMakeComputeEncoder
        }
        commandEncoder.setTexture(textureToFill, index: 0)
        commandEncoder.setTexture(initialConditionTexture, index: 1)
        var aSum = aSum
        commandEncoder.setBytes(&aSum, length: MemoryLayout<Float>.size, index: 0)
        var cSum = cSum
        commandEncoder.setBytes(&cSum, length: MemoryLayout<Float>.size, index: 1)
        commandEncoder.endEncoding()
    }
    
    static func finalFill(textureToFill: MTLTexture, initialConditionTexture: MTLTexture, library: MTLLibrary, device: MTLDevice, commandBuffer: MTLCommandBuffer) throws {
        let functionName = "iirMultiply"
        guard let function = library.makeFunction(name: functionName) else {
            throw Error.cantMakeFunction(functionName)
        }
        guard let commandEncoder = commandBuffer.makeComputeCommandEncoder() else {
            throw Error.cantMakeComputeEncoder
        }
        commandEncoder.setTexture(textureToFill, index: 0)
        commandEncoder.setTexture(initialConditionTexture, index: 1)
        commandEncoder.endEncoding()
    }
    
    func run(outputTexture: MTLTexture, commandBuffer: MTLCommandBuffer) throws {
        let needsUpdate: Bool
        if !(zTextures.count == numerators.count) {
            needsUpdate = true
        } else {
            needsUpdate = !zTextures.allSatisfy({ tex in
                tex.width == outputTexture.width && tex.height == outputTexture.height
            })
        }
        
        if needsUpdate {
            guard let initialConditionTexture = Self.texture(
                width: outputTexture.width,
                height: outputTexture.height,
                pixelFormat: outputTexture.pixelFormat,
                device: device
            ) else {
                throw Error.cantInstantiateTexture
            }
            let textures = Array(
                Self.textures(
                    width: outputTexture.width,
                    height: outputTexture.height,
                    pixelFormat: outputTexture.pixelFormat,
                    device: device
                )
                .prefix(numerators.count)
            )
            try Self.fillTextures(
                outputTexture: outputTexture,
                initialCondition: initialCondition,
                initialConditionTexture: initialConditionTexture,
                textures: textures,
                numerators: numerators,
                denominators: denominators,
                library: library,
                device: device,
                commandBuffer: commandBuffer
            )
            self.zTextures = textures
            self.scratchTexture = initialConditionTexture
        }
        
        let zTex0 = zTextures[0]
        let num0 = numerators[0]
        try Self.filterSample(
            outputTexture,
            zTex0: zTex0,
            filteredSampleTexture: scratchTexture!,
            num0: num0,
            library: library,
            commandBuffer: commandBuffer
        )
    }
    
    static func filterSample(_ inputTexture: MTLTexture, zTex0: MTLTexture, filteredSampleTexture: MTLTexture, num0: Float, library: MTLLibrary, commandBuffer: MTLCommandBuffer) throws {
        let functionName = "iirFilterSample"
        guard let function = library.makeFunction(name: functionName) else {
            throw Error.cantMakeFunction(functionName)
        }
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw Error.cantMakeComputeEncoder
        }
        encoder.setTexture(inputTexture, index: 0)
        encoder.setTexture(zTex0, index: 1)
        encoder.setTexture(filteredSampleTexture, index: 2)
        var num0 = num0
        encoder.setBytes(&num0, length: MemoryLayout<Float>.size, index: 0)
        encoder.endEncoding()
    }
}
