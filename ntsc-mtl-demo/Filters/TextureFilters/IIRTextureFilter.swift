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
    case invalidState(String)
}

extension IIRTextureFilter {
    typealias Error = TextureFilterError
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
    
    static func paint(
        texture: MTLTexture,
        with color: [Float16],
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
        commandEncoder.dispatchThreads(textureWidth: texture.width, textureHeight: texture.height)
        commandEncoder.endEncoding()
    }
}

class IIRTextureFilter {
//    typealias Error = IIRTextureFilterError
//    enum InitialCondition {
//        case zero
//        case firstSample
//        case constant([Float16])
//    }
//    
//    private let device: MTLDevice
//    private let pipelineCache: MetalPipelineCache
//    var numerators: [Float] = [] {
//        didSet {
//            if numerators != oldValue {
//                needsIIRUpdate = true
//            }
//        }
//    }
//    var denominators: [Float] = [] {
//        didSet {
//            if denominators != oldValue {
//                needsIIRUpdate = true
//            }
//        }
//    }
//    private var needsIIRUpdate: Bool = false
//    private let initialCondition: InitialCondition
//    private let channelMix: YIQChannels
//    var scale: Float16 = 1
//    var delay: UInt
//    private(set) var zTextures: [MTLTexture] = []
//    private var initialConditionTexture: MTLTexture?
//    private var filteredSampleTexture: MTLTexture?
//    private var spareTexture: MTLTexture?
//    private var filteredImageTexture: MTLTexture?
//    private var outputTexture: MTLTexture?
//    
//    init(device: MTLDevice, pipelineCache: MetalPipelineCache, initialCondition: InitialCondition, channels: YIQChannels, delay: UInt) {
//        self.device = device
//        self.pipelineCache = pipelineCache
//        self.initialCondition = initialCondition
//        self.channelMix = channels
//        self.delay = delay
//    }
//    
//    static func assertTextureIDsUnique(_ lhs: MTLTexture, _ rhs: MTLTexture) {
//        assert(ObjectIdentifier(lhs) != ObjectIdentifier(rhs))
//    }
//    
//    static func fillTexturesForInitialCondition(
//        inputTexture: MTLTexture,
//        initialCondition: InitialCondition,
//        initialConditionTexture: MTLTexture,
//        tempZ0Texture: MTLTexture,
//        zTextures: [MTLTexture],
//        numerators: [Float],
//        denominators: [Float],
//        device: MTLDevice,
//        pipelineCache: MetalPipelineCache,
//        commandBuffer: MTLCommandBuffer
//    ) throws {
//        switch initialCondition {
//        case .zero:
//            let input: [Float16] = [0, 0, 0, 1]   // black/zero
//            for tex in zTextures {
//                try paint(texture: tex, with: input, device: device, pipelineCache: pipelineCache, commandBuffer: commandBuffer)
//            }
//            return
//        case .firstSample:
//            try justBlit(from: inputTexture, to: initialConditionTexture, commandBuffer: commandBuffer)
//        case .constant(let color):
//            try paint(texture: initialConditionTexture, with: color, device: device, pipelineCache: pipelineCache, commandBuffer: commandBuffer)
//        }
//        
//        guard let firstNonZeroCoeff = denominators.first(where: { !$0.isZero }) else {
//            throw Error.noNonZeroDenominators
//        }
//        
//        let normalizedNumerators = numerators.map { num in
//            num / firstNonZeroCoeff
//        }
//        let normalizedDenominators = denominators.map { den in
//            den / firstNonZeroCoeff
//        }
//        
//        var bSum: Float = 0
//        for i in 1 ..< numerators.count {
//            let num = normalizedNumerators[i]
//            let den = normalizedDenominators[i]
//            bSum += num - (den * normalizedNumerators[0])
//        }
//        let z0Fill = bSum / normalizedDenominators.reduce(0, +)
//        let z0FillValues: [Float16] = [z0Fill, z0Fill, z0Fill, 1].map(Float16.init)
//        try paint(texture: tempZ0Texture, with: z0FillValues, device: device, pipelineCache: pipelineCache, commandBuffer: commandBuffer)
//        var aSum: Float = 1
//        var cSum: Float = 0
//        for i in 1 ..< numerators.count {
//            let num = normalizedNumerators[i]
//            let den = normalizedDenominators[i]
//            aSum += den
//            cSum += (num - (den * normalizedNumerators[0]))
//            assertTextureIDsUnique(inputTexture, initialConditionTexture)
//            assertTextureIDsUnique(initialConditionTexture, tempZ0Texture)
//            assertTextureIDsUnique(tempZ0Texture, zTextures[i])
//            assertTextureIDsUnique(zTextures[i], initialConditionTexture)
//            try initialConditionFill(
//                initialConditionTex: initialConditionTexture,
//                zTex0: tempZ0Texture,
//                zTexToFill: zTextures[i],
//                aSum: aSum,
//                cSum: cSum,
//                device: device,
//                pipelineCache: pipelineCache,
//                commandBuffer: commandBuffer
//            )
//        }
//        assertTextureIDsUnique(tempZ0Texture, initialConditionTexture)
//        assertTextureIDsUnique(initialConditionTexture, zTextures[0])
//        assertTextureIDsUnique(zTextures[0], tempZ0Texture)
//        
//        try finalZ0Fill(
//            z0InTexture: tempZ0Texture,
//            initialConditionTexture: initialConditionTexture,
//            z0OutTexture: zTextures[0],
//            device: device, 
//            pipelineCache: pipelineCache,
//            commandBuffer: commandBuffer
//        )
//    }
//    
//    static func paint(
//        texture: MTLTexture,
//        with color: [Float16],
//        device: MTLDevice,
//        pipelineCache: MetalPipelineCache,
//        commandBuffer: MTLCommandBuffer
//    ) throws {
//        let pipelineState: MTLComputePipelineState = try pipelineCache.pipelineState(function: .paint)
//        
//        guard let commandEncoder = commandBuffer.makeComputeCommandEncoder() else {
//            throw Error.cantMakeComputeEncoder
//        }
//        commandEncoder.setComputePipelineState(pipelineState)
//        commandEncoder.setTexture(texture, index: 0)
//        var color = color
//        commandEncoder.setBytes(&color, length: MemoryLayout<Float16>.size * 4, index: 0)
//        commandEncoder.dispatchThreads(textureWidth: texture.width, textureHeight: texture.height)
//        commandEncoder.endEncoding()
//    }
//    
//    static func initialConditionFill(
//        initialConditionTex: MTLTexture,
//        zTex0: MTLTexture,
//        zTexToFill: MTLTexture,
//        aSum: Float,
//        cSum: Float,
//        device: MTLDevice,
//        pipelineCache: MetalPipelineCache,
//        commandBuffer: MTLCommandBuffer
//    ) throws {
//        let pipelineState: MTLComputePipelineState = try pipelineCache.pipelineState(function: .iirInitialCondition)
//        
//        guard let commandEncoder = commandBuffer.makeComputeCommandEncoder() else {
//            throw Error.cantMakeComputeEncoder
//        }
//        commandEncoder.setComputePipelineState(pipelineState)
//        commandEncoder.setTexture(initialConditionTex, index: 0)
//        commandEncoder.setTexture(zTex0, index: 1)
//        commandEncoder.setTexture(zTexToFill, index: 2)
//        var aSum = aSum
//        commandEncoder.setBytes(&aSum, length: MemoryLayout<Float>.size, index: 0)
//        var cSum = cSum
//        commandEncoder.setBytes(&cSum, length: MemoryLayout<Float>.size, index: 1)
//        commandEncoder.dispatchThreads(textureWidth: zTexToFill.width, textureHeight: zTexToFill.height)
//        commandEncoder.endEncoding()
//    }
//    
//    static func finalZ0Fill(
//        z0InTexture: MTLTexture,
//        initialConditionTexture: MTLTexture,
//        z0OutTexture: MTLTexture,
//        device: MTLDevice,
//        pipelineCache: MetalPipelineCache,
//        commandBuffer: MTLCommandBuffer
//    ) throws {
//        let pipelineState: MTLComputePipelineState = try pipelineCache.pipelineState(function: .iirMultiply)
//        guard let commandEncoder = commandBuffer.makeComputeCommandEncoder() else {
//            throw Error.cantMakeComputeEncoder
//        }
//        commandEncoder.setComputePipelineState(pipelineState)
//        commandEncoder.setTexture(z0InTexture, index: 0)
//        commandEncoder.setTexture(initialConditionTexture, index: 1)
//        commandEncoder.setTexture(z0OutTexture, index: 1)
//        commandEncoder.dispatchThreads(textureWidth: z0InTexture.width, textureHeight: z0InTexture.height)
//        commandEncoder.endEncoding()
//    }
//    
//    func run(inputTexture: MTLTexture, outputTexture: MTLTexture, commandBuffer: MTLCommandBuffer) throws {
//        guard !(numerators.isEmpty || denominators.isEmpty) else {
//            try justBlit(from: inputTexture, to: outputTexture, commandBuffer: commandBuffer)
//            return
//        }
//        let needsTextureUpdate: Bool
//        if !(zTextures.count == numerators.count) {
//            needsTextureUpdate = true
//        } else {
//            needsTextureUpdate = !zTextures.allSatisfy({ tex in
//                tex.width == inputTexture.width && tex.height == inputTexture.height
//            })
//        }
//        
//        if needsTextureUpdate || needsIIRUpdate {
//            guard let initialConditionTexture = Self.texture(
//                from: inputTexture,
//                device: device
//            ) else {
//                throw Error.cantInstantiateTexture
//            }
//            
//            let filteredSampleTexture = initialConditionTexture
//            let zTextures = Array(
//                Self.textures(
//                    width: inputTexture.width,
//                    height: inputTexture.height,
//                    pixelFormat: inputTexture.pixelFormat,
//                    device: device
//                )
//                .prefix(numerators.count)
//            )
//            guard zTextures.count == numerators.count else {
//                throw Error.cantInstantiateTexture
//            }
//            
//            guard let tempZ0Texture = Self.texture(from: inputTexture, device: device) else {
//                throw Error.cantInstantiateTexture
//            }
//            
//            try Self.fillTexturesForInitialCondition(
//                inputTexture: inputTexture,
//                initialCondition: initialCondition,
//                initialConditionTexture: initialConditionTexture,
//                tempZ0Texture: tempZ0Texture,
//                zTextures: zTextures,
//                numerators: numerators,
//                denominators: denominators,
//                device: device,
//                pipelineCache: pipelineCache,
//                commandBuffer: commandBuffer)
//            self.zTextures = zTextures
//            self.initialConditionTexture = initialConditionTexture
//            self.filteredSampleTexture = filteredSampleTexture
//            self.filteredImageTexture = tempZ0Texture
//            self.needsIIRUpdate = false
//        }
//        
//        let zTex0 = zTextures[0]
//        let num0 = numerators[0]
//        
//        Self.assertTextureIDsUnique(inputTexture, zTex0)
//        Self.assertTextureIDsUnique(zTex0, filteredSampleTexture!)
//        Self.assertTextureIDsUnique(filteredSampleTexture!, inputTexture)
//        try Self.filterSample(
//            inputTexture: inputTexture,
//            zTex0: zTex0,
//            filteredSampleTexture: filteredSampleTexture!,
//            num0: num0,
//            device: device,
//            pipelineCache: pipelineCache,
//            commandBuffer: commandBuffer
//        )
//        
//        for i in numerators.indices {
//            let nextIdx = i + 1
//            guard nextIdx < numerators.count else {
//                break
//            }
//            let z = zTextures[i]
//            let zPlusOne = zTextures[nextIdx]
//            Self.assertTextureIDsUnique(inputTexture, z)
//            Self.assertTextureIDsUnique(z, zPlusOne)
//            Self.assertTextureIDsUnique(zPlusOne, filteredSampleTexture!)
//            Self.assertTextureIDsUnique(filteredSampleTexture!, inputTexture)
//            try Self.sideEffect(
//                inputImage: inputTexture,
//                z: z,
//                zPlusOne: zPlusOne,
//                filteredSample: filteredSampleTexture!,
//                numerator: numerators[nextIdx],
//                denominator: denominators[nextIdx],
//                device: device,
//                pipelineCache: pipelineCache,
//                commandBuffer: commandBuffer
//            )
//        }
//        Self.assertTextureIDsUnique(inputTexture, filteredSampleTexture!)
//        Self.assertTextureIDsUnique(filteredSampleTexture!, filteredImageTexture!)
//        Self.assertTextureIDsUnique(filteredImageTexture!, inputTexture)
//        try Self.filterImage(
//            inputImage: inputTexture,
//            filteredSample: filteredSampleTexture!,
//            outputTexture: filteredImageTexture!,
//            scale: scale,
//            device: device,
//            pipelineCache: pipelineCache,
//            commandBuffer: commandBuffer
//        )
//        Self.assertTextureIDsUnique(inputTexture, filteredSampleTexture!)
//        Self.assertTextureIDsUnique(filteredSampleTexture!, outputTexture)
//        Self.assertTextureIDsUnique(outputTexture, inputTexture)
//        try Self.finalCompose(
//            inputImage: inputTexture,
//            filteredImage: filteredSampleTexture!,
//            writingTo: outputTexture,
//            channels: self.channelMix,
//            delay: self.delay,
//            device: device, 
//            pipelineCache: pipelineCache,
//            commandBuffer: commandBuffer
//        )
//    }
//        
//    static func filterImage(
//        inputImage: MTLTexture,
//        filteredSample: MTLTexture,
//        outputTexture: MTLTexture,
//        scale: Float16,
//        device: MTLDevice,
//        pipelineCache: MetalPipelineCache,
//        commandBuffer: MTLCommandBuffer
//    ) throws {
//        let pipelineState: MTLComputePipelineState = try pipelineCache.pipelineState(function: .iirFinalImage)
//        guard let commandEncoder = commandBuffer.makeComputeCommandEncoder() else {
//            throw Error.cantMakeComputeEncoder
//        }
//        commandEncoder.setComputePipelineState(pipelineState)
//        commandEncoder.setTexture(inputImage, index: 0)
//        commandEncoder.setTexture(filteredSample, index: 1)
//        commandEncoder.setTexture(outputTexture, index: 2)
//        var scale = scale
//        commandEncoder.setBytes(&scale, length: MemoryLayout<Float16>.size, index: 0)
//        commandEncoder.dispatchThreads(textureWidth: inputImage.width, textureHeight: inputImage.height)
//        commandEncoder.endEncoding()
//    }
//    
//    
//    static func finalCompose(
//        inputImage: MTLTexture,
//        filteredImage: MTLTexture,
//        writingTo outputTexture: MTLTexture,
//        channels: YIQChannels,
//        delay: UInt,
//        device: MTLDevice,
//        pipelineCache: MetalPipelineCache,
//        commandBuffer: MTLCommandBuffer
//    ) throws {
//        let pipelineState: MTLComputePipelineState = try pipelineCache.pipelineState(function: .yiqCompose)
//        guard let commandEncoder = commandBuffer.makeComputeCommandEncoder() else {
//            throw Error.cantMakeComputeEncoder
//        }
//        commandEncoder.setComputePipelineState(pipelineState)
//        commandEncoder.setTexture(filteredImage, index: 0)
//        commandEncoder.setTexture(inputImage, index: 1)
//        commandEncoder.setTexture(outputTexture, index: 2)
//        var channelMix = channels.floatMix
//        commandEncoder.setBytes(&channelMix, length: MemoryLayout<Float16>.size * 4, index: 0)
//        var delay = delay
//        commandEncoder.setBytes(&delay, length: MemoryLayout<UInt>.size, index: 1)
//        commandEncoder.dispatchThreads(textureWidth: inputImage.width, textureHeight: inputImage.height)
//        commandEncoder.endEncoding()
//    }
//    
//    static func sideEffect(
//        inputImage: MTLTexture,
//        z: MTLTexture,
//        zPlusOne: MTLTexture,
//        filteredSample: MTLTexture,
//        numerator: Float,
//        denominator: Float,
//        device: MTLDevice,
//        pipelineCache: MetalPipelineCache,
//        commandBuffer: MTLCommandBuffer
//    ) throws {
//        let pipelineState: MTLComputePipelineState = try pipelineCache.pipelineState(function: .iirSideEffect)
//        guard let commandEncoder = commandBuffer.makeComputeCommandEncoder() else {
//            throw Error.cantMakeComputeEncoder
//        }
//        commandEncoder.setComputePipelineState(pipelineState)
//        commandEncoder.setTexture(inputImage, index: 0)
//        commandEncoder.setTexture(z, index: 1)
//        commandEncoder.setTexture(zPlusOne, index: 2)
//        commandEncoder.setTexture(filteredSample, index: 3)
//        var num = numerator
//        var denom = denominator
//        commandEncoder.setBytes(&num, length: MemoryLayout<Float>.size, index: 0)
//        commandEncoder.setBytes(&denom, length: MemoryLayout<Float>.size, index: 1)
//        commandEncoder.dispatchThreads(textureWidth: inputImage.width, textureHeight: inputImage.height)
//        commandEncoder.endEncoding()
//    }
//        
//    static func filterSample(inputTexture: MTLTexture, zTex0: MTLTexture, filteredSampleTexture: MTLTexture, num0: Float, device: MTLDevice, pipelineCache: MetalPipelineCache, commandBuffer: MTLCommandBuffer) throws {
//        let pipelineState: MTLComputePipelineState = try pipelineCache.pipelineState(function: .iirFilterSample)
//        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
//            throw Error.cantMakeComputeEncoder
//        }
//
//        encoder.setComputePipelineState(pipelineState)
//        encoder.setTexture(inputTexture, index: 0)
//        encoder.setTexture(zTex0, index: 1)
//        encoder.setTexture(filteredSampleTexture, index: 2)
//        var num0 = num0
//        encoder.setBytes(&num0, length: MemoryLayout<Float>.size, index: 0)
//        encoder.dispatchThreads(
//            MTLSize(width: inputTexture.width, height: inputTexture.height, depth: 1),
//            threadsPerThreadgroup: MTLSize(width: 8, height: 8, depth: 1))
//        encoder.endEncoding()
//    }
}
