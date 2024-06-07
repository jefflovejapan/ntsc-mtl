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
        case constant([Float16])
    }
    
    private static var iirInitialConditionPipelineState: MTLComputePipelineState?
    private static var iirMultiplyPipelineState: MTLComputePipelineState?
    private static var iirFinalImagePipelineState: MTLComputePipelineState?
    private static var yiqComposePipelineState: MTLComputePipelineState?
    private static var iirSideEffectPipelineState: MTLComputePipelineState?
    private static var iirFilterSamplePipelineState: MTLComputePipelineState?
    
    private let device: MTLDevice
    private let library: MTLLibrary
    private let numerators: [Float]
    private let denominators: [Float]
    private let initialCondition: InitialCondition
    private let channelMix: YIQChannels
    private let scale: Float16
    private(set) var zTextures: [MTLTexture] = []
    private var initialConditionTexture: MTLTexture?
    private var filteredSampleTexture: MTLTexture? {
        initialConditionTexture
    }
    private var spareTexture: MTLTexture?
    private var filteredImageTexture: MTLTexture?
    private var outputTexture: MTLTexture? {
        filteredSampleTexture
    }
    
    init(device: MTLDevice, library: MTLLibrary, numerators: [Float], denominators: [Float], initialCondition: InitialCondition, channels: YIQChannels, scale: Float16, delay: UInt) {
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
        self.channelMix = channels
        self.scale = scale
    }
    
    static func texture(from texture: (any MTLTexture), device: MTLDevice) -> MTLTexture? {
        return Self.texture(width: texture.width, height: texture.height, pixelFormat: texture.pixelFormat, device: device)
    }
    
    static func texture(width: Int, height: Int, pixelFormat: MTLPixelFormat, device: MTLDevice) -> MTLTexture? {
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: pixelFormat,
            width: width,
            height: height,
            mipmapped: false
        )
        textureDescriptor.usage = [.shaderRead, .shaderWrite, .renderTarget]
        return device.makeTexture(descriptor: textureDescriptor)
    }
    
    static func textures(from texture: MTLTexture, device: MTLDevice) -> AnySequence<MTLTexture> {
        let width = texture.width
        let height = texture.height
        let pixelFormat = texture.pixelFormat
        return AnySequence {
            AnyIterator {
                Self.texture(width: width, height: height, pixelFormat: pixelFormat, device: device)
            }
        }
    }
    
    static func textures(width: Int, height: Int, pixelFormat: MTLPixelFormat, device: MTLDevice) -> AnySequence<MTLTexture> {
        return AnySequence {
            return AnyIterator {
                return Self.texture(width: width, height: height, pixelFormat: pixelFormat, device: device)
            }
        }
    }
    
    
    /// WARN: Swaps zOutTexture with z[0]!!
    static func fillTexturesForInitialCondition(
        inputTexture: MTLTexture,
        initialCondition: InitialCondition,
        initialConditionTexture: MTLTexture,
        zTextures: inout [MTLTexture],
        zOutTexture: inout MTLTexture,
        numerators: [Float],
        denominators: [Float],
        library: MTLLibrary,
        device: MTLDevice,
        commandBuffer: MTLCommandBuffer
    ) throws {
        let region = MTLRegionMake2D(0, 0, inputTexture.width, inputTexture.height)
        let bytesPerRow: Int = MemoryLayout<Float16>.size * 4 * inputTexture.width
        switch initialCondition {
        case .zero:
            let input: [Float16] = [0, 0, 0, 1]   // black/zero
            var yiqa = input
            for tex in zTextures {
                tex.replace(region: region, mipmapLevel: 0, withBytes: &yiqa, bytesPerRow: bytesPerRow)
            }
            return
        case .firstSample:
            guard let blitEncoder = commandBuffer.makeBlitCommandEncoder() else {
                throw Error.cantMakeBlitEncoder
            }
            blitEncoder.copy(from: inputTexture, to: initialConditionTexture)
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
        let z0FillValues: [Float16] = [z0Fill, z0Fill, z0Fill, 1].map(Float16.init)
        var z0FillMutable = z0FillValues
        zTextures[0].replace(region: region, mipmapLevel: 0, withBytes: &z0FillMutable, bytesPerRow: bytesPerRow)
        var aSum: Float = 1
        var cSum: Float = 0
        for i in 1 ..< numerators.count {
            let num = normalizedNumerators[i]
            let den = normalizedDenominators[i]
            aSum += den
            cSum += (num - (den * normalizedNumerators[0]))
            try initialConditionFill(
                initialConditionTex: initialConditionTexture,
                zTex0: zTextures[0],
                zTexToFill: zTextures[i],
                aSum: aSum,
                cSum: cSum,
                library: library,
                device: device,
                commandBuffer: commandBuffer
            )
        }
        try finalZ0Fill(
            z0InTexture: zTextures[0],
            initialConditionTexture: initialConditionTexture,
            z0OutTexture: zOutTexture,
            library: library,
            device: device,
            commandBuffer: commandBuffer
        )
        let oldZ0 = zTextures[0]
        let zOut = zOutTexture
        zTextures[0] = zOut
        zOutTexture = oldZ0
    }
    
    private static func initialConditionFill(
        initialConditionTex: MTLTexture,
        zTex0: MTLTexture,
        zTexToFill: MTLTexture,
        aSum: Float,
        cSum: Float,
        library: MTLLibrary,
        device: MTLDevice,
        commandBuffer: MTLCommandBuffer
    ) throws {
        let pipelineState: MTLComputePipelineState
        if let iirInitialConditionPipelineState {
            pipelineState = iirInitialConditionPipelineState
        } else {
            let functionName = "iirInitialCondition"
            guard let function = library.makeFunction(name: functionName) else {
                throw Error.cantMakeFunction(functionName)
            }
            pipelineState = try device.makeComputePipelineState(function: function)
            Self.iirInitialConditionPipelineState = pipelineState
        }
        
        guard let commandEncoder = commandBuffer.makeComputeCommandEncoder() else {
            throw Error.cantMakeComputeEncoder
        }
        commandEncoder.setComputePipelineState(pipelineState)
        commandEncoder.setTexture(initialConditionTex, index: 0)
        commandEncoder.setTexture(zTex0, index: 1)
        commandEncoder.setTexture(zTexToFill, index: 2)
        var aSum = aSum
        commandEncoder.setBytes(&aSum, length: MemoryLayout<Float>.size, index: 0)
        var cSum = cSum
        commandEncoder.setBytes(&cSum, length: MemoryLayout<Float>.size, index: 1)
        commandEncoder.dispatchThreads(
            MTLSize(width: zTexToFill.width, height: zTexToFill.height, depth: 1),
            threadsPerThreadgroup: MTLSize(width: 8, height: 8, depth: 1))
        commandEncoder.endEncoding()
    }
    
    static func finalZ0Fill(
        z0InTexture: MTLTexture,
        initialConditionTexture: MTLTexture,
        z0OutTexture: MTLTexture,
        library: MTLLibrary,
        device: MTLDevice,
        commandBuffer: MTLCommandBuffer
    ) throws {
        let pipelineState: MTLComputePipelineState
        if let iirMultiplyPipelineState {
            pipelineState = iirMultiplyPipelineState
        } else {
            let functionName = "iirMultiply"
            guard let function = library.makeFunction(name: functionName) else {
                throw Error.cantMakeFunction(functionName)
            }
            pipelineState = try device.makeComputePipelineState(function: function)
            Self.iirMultiplyPipelineState = pipelineState
        }
        guard let commandEncoder = commandBuffer.makeComputeCommandEncoder() else {
            throw Error.cantMakeComputeEncoder
        }
        commandEncoder.setComputePipelineState(pipelineState)
        commandEncoder.setTexture(z0InTexture, index: 0)
        commandEncoder.setTexture(initialConditionTexture, index: 1)
        commandEncoder.setTexture(z0OutTexture, index: 1)
        commandEncoder.dispatchThreads(
            MTLSize(width: z0InTexture.width, height: z0InTexture.height, depth: 1),
            threadsPerThreadgroup: MTLSize(width: 8, height: 8, depth: 1))
        commandEncoder.endEncoding()
    }
    
    func run(inputTexture: MTLTexture, outputTexture: MTLTexture, commandBuffer: MTLCommandBuffer) throws {
        let needsUpdate: Bool
        if !(zTextures.count == numerators.count) {
            needsUpdate = true
        } else {
            needsUpdate = !zTextures.allSatisfy({ tex in
                tex.width == inputTexture.width && tex.height == inputTexture.height
            })
        }
        
        if needsUpdate {
            guard let initialConditionTexture = Self.texture(
                from: inputTexture,
                device: device
            ) else {
                throw Error.cantInstantiateTexture
            }
            
            let filteredSampleTexture = initialConditionTexture
            
            guard let filteredImageTexture = Self.texture(from: inputTexture, device: device) else {
                throw Error.cantInstantiateTexture
            }
            
            let finalOutputTexture = filteredImageTexture
            
            var zTextures = Array(
                Self.textures(
                    width: inputTexture.width,
                    height: inputTexture.height,
                    pixelFormat: inputTexture.pixelFormat,
                    device: device
                )
                .prefix(numerators.count)
            )
            guard zTextures.count == numerators.count else {
                throw Error.cantInstantiateTexture
            }
            
            guard var zOutTexture = Self.texture(from: inputTexture, device: device) else {
                throw Error.cantInstantiateTexture
            }
            try Self.fillTexturesForInitialCondition(
                inputTexture: inputTexture,
                initialCondition: initialCondition,
                initialConditionTexture: initialConditionTexture,
                zTextures: &zTextures,
                zOutTexture: &zOutTexture,
                numerators: numerators,
                denominators: denominators,
                library: library,
                device: device,
                commandBuffer: commandBuffer)
            self.zTextures = zTextures
            self.initialConditionTexture = initialConditionTexture
            self.spareTexture = zOutTexture
        }
        
        let zTex0 = zTextures[0]
        let num0 = numerators[0]
        try Self.filterSample(
            inputTexture,
            zTex0: zTex0,
            filteredSampleTexture: filteredSampleTexture!,
            num0: num0,
            library: library,
            device: device,
            commandBuffer: commandBuffer
        )
        
        for i in numerators.indices {
            let nextIdx = i + 1
            guard nextIdx < numerators.count else {
                break
            }
            let z = zTextures[i]
            let zPlusOne = zTextures[nextIdx]
            try Self.sideEffect(
                inputImage: inputTexture,
                z: z,
                zPlusOne: zPlusOne,
                filteredSample: filteredSampleTexture!,
                numerator: numerators[nextIdx],
                denominator: denominators[nextIdx],
                library: library,
                device: device,
                commandBuffer: commandBuffer
            )
        }
        try Self.filterImage(
            inputImage: inputTexture,
            filteredImage: filteredSampleTexture!,
            scale: scale,
            library: library,
            device: device,
            commandBuffer: commandBuffer
        )
        try Self.finalCompose(
            inputImage: inputTexture,
            filteredImage: filteredSampleTexture!,
            writingTo: outputTexture,
            channels: self.channelMix,
            library: library,
            device: device,
            commandBuffer: commandBuffer
        )
    }
        
    static func filterImage(
        inputImage: MTLTexture,
        filteredImage: MTLTexture,
        scale: Float16,
        library: MTLLibrary,
        device: MTLDevice,
        commandBuffer: MTLCommandBuffer
    ) throws {
        let pipelineState: MTLComputePipelineState
        if let iirFinalImagePipelineState {
            pipelineState = iirFinalImagePipelineState
        } else {
            let functionName = "iirFinalImage"
            guard let function = library.makeFunction(name: functionName) else {
                throw Error.cantMakeFunction(functionName)
            }
            pipelineState = try device.makeComputePipelineState(function: function)
            Self.iirFinalImagePipelineState = pipelineState
        }
        guard let commandEncoder = commandBuffer.makeComputeCommandEncoder() else {
            throw Error.cantMakeComputeEncoder
        }
        commandEncoder.setComputePipelineState(pipelineState)
        commandEncoder.setTexture(inputImage, index: 0)
        commandEncoder.setTexture(filteredImage, index: 1)
        var scale = scale
        commandEncoder.setBytes(&scale, length: MemoryLayout<Float16>.size, index: 0)
        commandEncoder.dispatchThreads(
            MTLSize(width: inputImage.width, height: inputImage.height, depth: 1),
            threadsPerThreadgroup: MTLSize(width: 8, height: 8, depth: 1))
        commandEncoder.endEncoding()
    }
    
    
    static func finalCompose(inputImage: MTLTexture, filteredImage: MTLTexture, writingTo outputTexture: MTLTexture, channels: YIQChannels, library: MTLLibrary, device: MTLDevice, commandBuffer: MTLCommandBuffer) throws {
        let pipelineState: MTLComputePipelineState
        if let yiqComposePipelineState {
            pipelineState = yiqComposePipelineState
        } else {
            let functionName = "yiqCompose"
            guard let function = library.makeFunction(name: functionName) else {
                throw Error.cantMakeFunction(functionName)
            }
            pipelineState = try device.makeComputePipelineState(function: function)
            Self.yiqComposePipelineState = pipelineState
        }
        guard let commandEncoder = commandBuffer.makeComputeCommandEncoder() else {
            throw Error.cantMakeComputeEncoder
        }
        commandEncoder.setComputePipelineState(pipelineState)
        commandEncoder.setTexture(filteredImage, index: 0)
        commandEncoder.setTexture(inputImage, index: 1)
        commandEncoder.setTexture(outputTexture, index: 2)
        var channelMix = channels.floatMix
        commandEncoder.setBytes(&channelMix, length: MemoryLayout<Float16>.size * 4, index: 0)
        commandEncoder.dispatchThreads(
            MTLSize(width: inputImage.width, height: inputImage.height, depth: 1),
            threadsPerThreadgroup: MTLSize(width: 8, height: 8, depth: 1))
        commandEncoder.endEncoding()
    }
    

    
    static func sideEffect(inputImage: MTLTexture, z: MTLTexture, zPlusOne: MTLTexture, filteredSample: MTLTexture, numerator: Float, denominator: Float, library: MTLLibrary, device: MTLDevice, commandBuffer: MTLCommandBuffer) throws {
        let pipelineState: MTLComputePipelineState
        if let iirSideEffectPipelineState {
            pipelineState = iirSideEffectPipelineState
        } else {
            let functionName = "iirSideEffect"
            guard let function = library.makeFunction(name: functionName) else {
                throw Error.cantMakeFunction(functionName)
            }
            pipelineState = try device.makeComputePipelineState(function: function)
            Self.iirSideEffectPipelineState = pipelineState
        }
        guard let commandEncoder = commandBuffer.makeComputeCommandEncoder() else {
            throw Error.cantMakeComputeEncoder
        }
        commandEncoder.setComputePipelineState(pipelineState)
        commandEncoder.setTexture(inputImage, index: 0)
        commandEncoder.setTexture(z, index: 1)
        commandEncoder.setTexture(zPlusOne, index: 2)
        commandEncoder.setTexture(filteredSample, index: 3)
        var num = numerator
        var denom = denominator
        commandEncoder.setBytes(&num, length: MemoryLayout<Float>.size, index: 0)
        commandEncoder.setBytes(&denom, length: MemoryLayout<Float>.size, index: 1)
        commandEncoder.dispatchThreads(
            MTLSize(width: inputImage.width, height: inputImage.height, depth: 1),
            threadsPerThreadgroup: MTLSize(width: 8, height: 8, depth: 1))
        commandEncoder.endEncoding()
    }
        
    static func filterSample(_ inputTexture: MTLTexture, zTex0: MTLTexture, filteredSampleTexture: MTLTexture, num0: Float, library: MTLLibrary, device: MTLDevice, commandBuffer: MTLCommandBuffer) throws {
        let pipelineState: MTLComputePipelineState
        if let iirFilterSamplePipelineState {
            pipelineState = iirFilterSamplePipelineState
        } else {
            let functionName = "iirFilterSample"
            guard let function = library.makeFunction(name: functionName) else {
                throw Error.cantMakeFunction(functionName)
            }
            pipelineState = try device.makeComputePipelineState(function: function)
            Self.iirFilterSamplePipelineState = pipelineState
        }
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw Error.cantMakeComputeEncoder
        }

        encoder.setComputePipelineState(pipelineState)
        encoder.setTexture(inputTexture, index: 0)
        encoder.setTexture(zTex0, index: 1)
        encoder.setTexture(filteredSampleTexture, index: 2)
        var num0 = num0
        encoder.setBytes(&num0, length: MemoryLayout<Float>.size, index: 0)
        encoder.dispatchThreads(
            MTLSize(width: inputTexture.width, height: inputTexture.height, depth: 1),
            threadsPerThreadgroup: MTLSize(width: 8, height: 8, depth: 1))
        encoder.endEncoding()
    }
}
