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
    
    private let device: MTLDevice
    private let library: MTLLibrary
    private let pipelineCache: MetalPipelineCache
    private let numerators: [Float]
    private let denominators: [Float]
    private let initialCondition: InitialCondition
    private let channelMix: YIQChannels
    private let scale: Float16
    private(set) var zTextures: [MTLTexture] = []
    private var initialConditionTexture: MTLTexture?
    private var filteredSampleTexture: MTLTexture?
    private var spareTexture: MTLTexture?
    private var filteredImageTexture: MTLTexture?
    private var outputTexture: MTLTexture?
    
    init(device: MTLDevice, library: MTLLibrary, pipelineCache: MetalPipelineCache, numerators: [Float], denominators: [Float], initialCondition: InitialCondition, channels: YIQChannels, scale: Float16, delay: UInt) {
        self.device = device
        self.library = library
        self.pipelineCache = pipelineCache
        self.numerators = numerators
        self.denominators = denominators
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
    
    static func assertTextureIDsUnique(_ lhs: MTLTexture, _ rhs: MTLTexture) {
        assert(ObjectIdentifier(lhs) != ObjectIdentifier(rhs))
    }
    
    static func fillTexturesForInitialCondition(
        inputTexture: MTLTexture,
        initialCondition: InitialCondition,
        initialConditionTexture: MTLTexture,
        tempZ0Texture: MTLTexture,
        zTextures: [MTLTexture],
        numerators: [Float],
        denominators: [Float],
        library: MTLLibrary,
        device: MTLDevice,
        pipelineCache: MetalPipelineCache,
        commandBuffer: MTLCommandBuffer
    ) throws {
        switch initialCondition {
        case .zero:
            let input: [Float16] = [0, 0, 0, 1]   // black/zero
            for tex in zTextures {
                try paint(texture: tex, with: input, library: library, device: device, pipelineCache: pipelineCache, commandBuffer: commandBuffer)
            }
            return
        case .firstSample:
            guard let blitEncoder = commandBuffer.makeBlitCommandEncoder() else {
                throw Error.cantMakeBlitEncoder
            }
            blitEncoder.copy(from: inputTexture, to: initialConditionTexture)
            blitEncoder.endEncoding()
        case .constant(let color):
            try paint(texture: initialConditionTexture, with: color, library: library, device: device, pipelineCache: pipelineCache, commandBuffer: commandBuffer)
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
        try paint(texture: tempZ0Texture, with: z0FillValues, library: library, device: device, pipelineCache: pipelineCache, commandBuffer: commandBuffer)
        var aSum: Float = 1
        var cSum: Float = 0
        for i in 1 ..< numerators.count {
            let num = normalizedNumerators[i]
            let den = normalizedDenominators[i]
            aSum += den
            cSum += (num - (den * normalizedNumerators[0]))
            assertTextureIDsUnique(inputTexture, initialConditionTexture)
            assertTextureIDsUnique(initialConditionTexture, tempZ0Texture)
            assertTextureIDsUnique(tempZ0Texture, zTextures[i])
            assertTextureIDsUnique(zTextures[i], initialConditionTexture)
            try initialConditionFill(
                initialConditionTex: initialConditionTexture,
                zTex0: tempZ0Texture,
                zTexToFill: zTextures[i],
                aSum: aSum,
                cSum: cSum,
                library: library,
                device: device, 
                pipelineCache: pipelineCache,
                commandBuffer: commandBuffer
            )
        }
        assertTextureIDsUnique(tempZ0Texture, initialConditionTexture)
        assertTextureIDsUnique(initialConditionTexture, zTextures[0])
        assertTextureIDsUnique(zTextures[0], tempZ0Texture)
        
        try finalZ0Fill(
            z0InTexture: tempZ0Texture,
            initialConditionTexture: initialConditionTexture,
            z0OutTexture: zTextures[0],
            library: library,
            device: device, 
            pipelineCache: pipelineCache,
            commandBuffer: commandBuffer
        )
    }
    
    static func paint(
        texture: MTLTexture,
        with color: [Float16],
        library: MTLLibrary,
        device: MTLDevice,
        pipelineCache: MetalPipelineCache,
        commandBuffer: MTLCommandBuffer
    ) throws {
        let pipelineState: MTLComputePipelineState = try pipelineCache.pipelineState(function: .paint)
        
        guard let commandEncoder = commandBuffer.makeComputeCommandEncoder() else {
            throw Error.cantMakeComputeEncoder
        }
        commandEncoder.setComputePipelineState(pipelineState)
        commandEncoder.setTexture(texture, index: 0)
        var color = color
        commandEncoder.setBytes(&color, length: MemoryLayout<Float16>.size * 4, index: 0)
        commandEncoder.dispatchThreads(
            MTLSize(width: texture.width, height: texture.height, depth: 1),
            threadsPerThreadgroup: MTLSize(width: 8, height: 8, depth: 1))
        commandEncoder.endEncoding()
    }
    
    static func initialConditionFill(
        initialConditionTex: MTLTexture,
        zTex0: MTLTexture,
        zTexToFill: MTLTexture,
        aSum: Float,
        cSum: Float,
        library: MTLLibrary,
        device: MTLDevice,
        pipelineCache: MetalPipelineCache,
        commandBuffer: MTLCommandBuffer
    ) throws {
        let pipelineState: MTLComputePipelineState = try pipelineCache.pipelineState(function: .iirInitialCondition)
        
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
        pipelineCache: MetalPipelineCache,
        commandBuffer: MTLCommandBuffer
    ) throws {
        let pipelineState: MTLComputePipelineState = try pipelineCache.pipelineState(function: .iirMultiply)
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
            let zTextures = Array(
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
            
            guard let tempZ0Texture = Self.texture(from: inputTexture, device: device) else {
                throw Error.cantInstantiateTexture
            }
            
            try Self.fillTexturesForInitialCondition(
                inputTexture: inputTexture,
                initialCondition: initialCondition,
                initialConditionTexture: initialConditionTexture,
                tempZ0Texture: tempZ0Texture,
                zTextures: zTextures,
                numerators: numerators,
                denominators: denominators,
                library: library,
                device: device, 
                pipelineCache: pipelineCache,
                commandBuffer: commandBuffer)
            self.zTextures = zTextures
            self.initialConditionTexture = initialConditionTexture
            self.filteredSampleTexture = filteredSampleTexture
            self.filteredImageTexture = tempZ0Texture
        }
        
        let zTex0 = zTextures[0]
        let num0 = numerators[0]
        
        Self.assertTextureIDsUnique(inputTexture, zTex0)
        Self.assertTextureIDsUnique(zTex0, filteredSampleTexture!)
        Self.assertTextureIDsUnique(filteredSampleTexture!, inputTexture)
        try Self.filterSample(
            inputTexture: inputTexture,
            zTex0: zTex0,
            filteredSampleTexture: filteredSampleTexture!,
            num0: num0,
            library: library,
            device: device, 
            pipelineCache: pipelineCache,
            commandBuffer: commandBuffer
        )
        
        for i in numerators.indices {
            let nextIdx = i + 1
            guard nextIdx < numerators.count else {
                break
            }
            let z = zTextures[i]
            let zPlusOne = zTextures[nextIdx]
            Self.assertTextureIDsUnique(inputTexture, z)
            Self.assertTextureIDsUnique(z, zPlusOne)
            Self.assertTextureIDsUnique(zPlusOne, filteredSampleTexture!)
            Self.assertTextureIDsUnique(filteredSampleTexture!, inputTexture)
            try Self.sideEffect(
                inputImage: inputTexture,
                z: z,
                zPlusOne: zPlusOne,
                filteredSample: filteredSampleTexture!,
                numerator: numerators[nextIdx],
                denominator: denominators[nextIdx],
                library: library,
                device: device, 
                pipelineCache: pipelineCache,
                commandBuffer: commandBuffer
            )
        }
        Self.assertTextureIDsUnique(inputTexture, filteredSampleTexture!)
        Self.assertTextureIDsUnique(filteredSampleTexture!, filteredImageTexture!)
        Self.assertTextureIDsUnique(filteredImageTexture!, inputTexture)
        try Self.filterImage(
            inputImage: inputTexture,
            filteredSample: filteredSampleTexture!,
            outputTexture: filteredImageTexture!,
            scale: scale,
            library: library,
            device: device, 
            pipelineCache: pipelineCache,
            commandBuffer: commandBuffer
        )
        Self.assertTextureIDsUnique(inputTexture, filteredSampleTexture!)
        Self.assertTextureIDsUnique(filteredSampleTexture!, outputTexture)
        Self.assertTextureIDsUnique(outputTexture, inputTexture)
        try Self.finalCompose(
            inputImage: inputTexture,
            filteredImage: filteredSampleTexture!,
            writingTo: outputTexture,
            channels: self.channelMix,
            library: library,
            device: device, 
            pipelineCache: pipelineCache,
            commandBuffer: commandBuffer
        )
    }
        
    static func filterImage(
        inputImage: MTLTexture,
        filteredSample: MTLTexture,
        outputTexture: MTLTexture,
        scale: Float16,
        library: MTLLibrary,
        device: MTLDevice,
        pipelineCache: MetalPipelineCache,
        commandBuffer: MTLCommandBuffer
    ) throws {
        let pipelineState: MTLComputePipelineState = try pipelineCache.pipelineState(function: .iirFinalImage)
        guard let commandEncoder = commandBuffer.makeComputeCommandEncoder() else {
            throw Error.cantMakeComputeEncoder
        }
        commandEncoder.setComputePipelineState(pipelineState)
        commandEncoder.setTexture(inputImage, index: 0)
        commandEncoder.setTexture(filteredSample, index: 1)
        commandEncoder.setTexture(outputTexture, index: 2)
        var scale = scale
        commandEncoder.setBytes(&scale, length: MemoryLayout<Float16>.size, index: 0)
        commandEncoder.dispatchThreads(
            MTLSize(width: inputImage.width, height: inputImage.height, depth: 1),
            threadsPerThreadgroup: MTLSize(width: 8, height: 8, depth: 1))
        commandEncoder.endEncoding()
    }
    
    
    static func finalCompose(inputImage: MTLTexture, filteredImage: MTLTexture, writingTo outputTexture: MTLTexture, channels: YIQChannels, library: MTLLibrary, device: MTLDevice, pipelineCache: MetalPipelineCache, commandBuffer: MTLCommandBuffer) throws {
        let pipelineState: MTLComputePipelineState = try pipelineCache.pipelineState(function: .yiqCompose)
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
    

    
    static func sideEffect(inputImage: MTLTexture, z: MTLTexture, zPlusOne: MTLTexture, filteredSample: MTLTexture, numerator: Float, denominator: Float, library: MTLLibrary, device: MTLDevice, pipelineCache: MetalPipelineCache, commandBuffer: MTLCommandBuffer) throws {
        let pipelineState: MTLComputePipelineState = try pipelineCache.pipelineState(function: .iirSideEffect)
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
        
    static func filterSample(inputTexture: MTLTexture, zTex0: MTLTexture, filteredSampleTexture: MTLTexture, num0: Float, library: MTLLibrary, device: MTLDevice, pipelineCache: MetalPipelineCache, commandBuffer: MTLCommandBuffer) throws {
        let pipelineState: MTLComputePipelineState = try pipelineCache.pipelineState(function: .iirFilterSample)
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
