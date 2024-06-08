//
//  IIRTextureFilter.swift
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-06-03.
//

import Foundation
import CoreImage
import Metal

enum TextureFilterError: Swift.Error {
    case cantInstantiateTexture
    case cantMakeCommandQueue
    case cantMakeCommandBuffer
    case cantMakeComputeEncoder
    case cantMakeLibrary
    case cantMakeRandomImage
    case cantMakeFunction(String)
    case cantMakeBlitEncoder
    case logicHole(String)
}

class NTSCTextureFilter {
    typealias Error = TextureFilterError
    private var textureA: MTLTexture!
    private var textureB: MTLTexture!
    private var textureC: MTLTexture!
    private let device: MTLDevice
    private let context: CIContext
    private let commandQueue: MTLCommandQueue
    private let library: MTLLibrary
    var effect: NTSCEffect
    
    // MARK: -Filters
    private let lumaBoxFilter: LumaBoxTextureFilter
    private let lumaNotchFilter: IIRTextureFilter
    private let lightChromaLowpassFilter: ChromaLowpassTextureFilter
    private let fullChromaLowpassFilter: ChromaLowpassTextureFilter
    private let chromaIntoLumaFilter: ChromaIntoLumaTextureFilter
    private let compositePreemphasisFilter: IIRTextureFilter
    private let compositeNoiseFilter: CompositeNoiseTextureFilter
    private let snowFilter: SnowTextureFilter
    private let headSwitchingFilter: HeadSwitchingTextureFilter
    
    init(effect: NTSCEffect, device: MTLDevice, context: CIContext) throws {
        self.effect = effect
        self.device = device
        self.context = context
        guard let commandQueue = device.makeCommandQueue() else {
            throw Error.cantInstantiateTexture
        }
        self.commandQueue = commandQueue
        guard let library = device.makeDefaultLibrary() else {
            throw Error.cantMakeLibrary
        }
        self.library = library
        self.lumaBoxFilter = LumaBoxTextureFilter(device: device, commandQueue: commandQueue, library: library)
        let lumaNotchTransferFunction = IIRTransferFunction.lumaNotch
        self.lumaNotchFilter = IIRTextureFilter(
            device: device,
            library: library,
            numerators: lumaNotchTransferFunction.numerators,
            denominators: lumaNotchTransferFunction.denominators,
            initialCondition: .firstSample,
            channels: .y,
            scale: 1,
            delay: 0
        )
        self.lightChromaLowpassFilter = ChromaLowpassTextureFilter(device: device, library: library, intensity: .light, bandwidthScale: effect.bandwidthScale, filterType: effect.filterType)
        self.fullChromaLowpassFilter = ChromaLowpassTextureFilter(device: device, library: library, intensity: .full, bandwidthScale: effect.bandwidthScale, filterType: effect.filterType)
        self.chromaIntoLumaFilter = ChromaIntoLumaTextureFilter()
        let compositePreemphasisFunction = IIRTransferFunction.compositePreemphasis(bandwidthScale: effect.bandwidthScale)
        self.compositePreemphasisFilter = IIRTextureFilter(
            device: device,
            library: library,
            numerators: compositePreemphasisFunction.numerators,
            denominators: compositePreemphasisFunction.denominators,
            initialCondition: .zero,
            channels: .y,
            scale: -effect.compositePreemphasis,
            delay: 0
        )
        self.compositeNoiseFilter = CompositeNoiseTextureFilter(noise: effect.compositeNoise, device: device, library: library, ciContext: context)
        self.snowFilter = SnowTextureFilter(device: device, library: library, ciContext: context)
        self.headSwitchingFilter = HeadSwitchingTextureFilter(device: device, library: library, ciContext: context)
    }
    
    var inputImage: CIImage?
    
    private static var convertToYIQPipelineState: MTLComputePipelineState?
    
    static func convertToYIQ(_ texture: (any MTLTexture), output: (any MTLTexture), library: MTLLibrary, commandBuffer: MTLCommandBuffer, device: MTLDevice) throws {
        // Create a command buffer and encoder
        guard let commandEncoder = commandBuffer.makeComputeCommandEncoder() else {
            throw Error.cantMakeComputeEncoder
        }
        
        let pipelineState: MTLComputePipelineState
        if let convertToYIQPipelineState {
            pipelineState = convertToYIQPipelineState
        } else {
            let functionName = "convertToYIQ"
            guard let function = library.makeFunction(name: functionName) else {
                throw Error.cantMakeFunction(functionName)
            }
            pipelineState = try device.makeComputePipelineState(function: function)
            Self.convertToYIQPipelineState = pipelineState
        }
        
        commandEncoder.setComputePipelineState(pipelineState)
        
        // Set the texture and dispatch threads
        commandEncoder.setTexture(texture, index: 0)
        commandEncoder.setTexture(output, index: 1)
        commandEncoder.dispatchThreads(
            MTLSize(width: texture.width, height: texture.height, depth: 1),
            threadsPerThreadgroup: MTLSize(width: 8, height: 8, depth: 1)
        )
        
        // Finalize encoding
        commandEncoder.endEncoding()
    }
    
    static func inputLuma(
        _ texture: (any MTLTexture),
        output: (any MTLTexture),
        commandBuffer: MTLCommandBuffer,
        lumaLowpass: LumaLowpass,
        lumaBoxFilter: LumaBoxTextureFilter,
        lumaNotchFilter: IIRTextureFilter
    ) throws {
        switch lumaLowpass {
        case .none:
            return
        case .box:
            try lumaBoxFilter.run(inputTexture: texture, outputTexture: output, commandBuffer: commandBuffer)
        case .notch:
            try lumaNotchFilter.run(inputTexture: texture, outputTexture: output, commandBuffer: commandBuffer)
        }
    }
    
    static func chromaLowpass(
        _ texture: (any MTLTexture),
        output: (any MTLTexture),
        commandBuffer: MTLCommandBuffer,
        chromaLowpass: ChromaLowpass,
        lightFilter: ChromaLowpassTextureFilter,
        fullFilter: ChromaLowpassTextureFilter
    ) throws {
        switch chromaLowpass {
        case .none:
            return
        case .light:
            try lightFilter.run(inputTexture: texture, outputTexture: output, commandBuffer: commandBuffer)
        case .full:
            try fullFilter.run(inputTexture: texture, outputTexture: output, commandBuffer: commandBuffer)
        }
    }
    
    static func chromaIntoLuma(inputTexture: MTLTexture, outputTexture: MTLTexture, timestamp: UInt32, phaseShift: PhaseShift, phaseShiftOffset: Int, filter: ChromaIntoLumaTextureFilter, library: MTLLibrary, device: MTLDevice, commandBuffer: MTLCommandBuffer) throws {
        try filter.run(
            inputTexture: inputTexture,
            outputTexture: outputTexture,
            timestamp: timestamp,
            phaseShift: phaseShift,
            phaseShiftOffset: phaseShiftOffset,
            library: library,
            device: device,
            commandBuffer: commandBuffer
        )
    }
    
    static func compositePreemphasis(inputTexture: MTLTexture, outputTexture: MTLTexture, filter: IIRTextureFilter, commandBuffer: MTLCommandBuffer) throws {
        try filter.run(inputTexture: inputTexture, outputTexture: outputTexture, commandBuffer: commandBuffer)
    }
    
    static func compositeNoise(inputTexture: MTLTexture, outputTexture: MTLTexture, filter: CompositeNoiseTextureFilter, commandBuffer: MTLCommandBuffer) throws {
        try filter.run(inputTexture: inputTexture, outputTexture: outputTexture, commandBuffer: commandBuffer)
    }
    
    static func snow(inputTexture: MTLTexture, outputTexture: MTLTexture, filter: SnowTextureFilter, commandBuffer: MTLCommandBuffer) throws {
        try filter.run(inputTexture: inputTexture, outputTexture: outputTexture, commandBuffer: commandBuffer)
    }
    
    static func headSwitching(inputTexture: MTLTexture, outputTexture: MTLTexture, filter: HeadSwitchingTextureFilter, headSwitching: HeadSwitchingSettings?, commandBuffer: MTLCommandBuffer) throws {
        filter.headSwitchingSettings = headSwitching
        try filter.run(inputTexture: inputTexture, outputTexture: outputTexture, commandBuffer: commandBuffer)
    }
    
    private static var convertToRGBPipelineState: MTLComputePipelineState?
    
    static func convertToRGB(_ texture: (any MTLTexture), output: (any MTLTexture), commandBuffer: MTLCommandBuffer, library: MTLLibrary, device: MTLDevice) throws {
        // Create a command buffer and encoder
        guard let commandEncoder = commandBuffer.makeComputeCommandEncoder() else {
            throw Error.cantMakeComputeEncoder
        }
        
        let pipelineState: MTLComputePipelineState
        if let convertToRGBPipelineState {
            pipelineState = convertToRGBPipelineState
        } else {
            let functionName = "convertToRGB"
            guard let function = library.makeFunction(name: functionName) else {
                throw Error.cantMakeFunction(functionName)
            }
            pipelineState = try device.makeComputePipelineState(function: function)
            self.convertToRGBPipelineState = pipelineState
        }
        
        // Set up the compute pipeline
        commandEncoder.setComputePipelineState(pipelineState)
        
        // Set the texture and dispatch threads
        commandEncoder.setTexture(texture, index: 0)
        commandEncoder.setTexture(output, index: 1)
        commandEncoder.dispatchThreads(
            MTLSize(width: texture.width, height: texture.height, depth: 1),
            threadsPerThreadgroup: MTLSize(width: 8, height: 8, depth: 1))
        
        commandEncoder.endEncoding()
    }
    
    private func setup(with inputImage: CIImage) throws {
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            throw Error.cantMakeCommandBuffer
        }
        
        defer {
            commandBuffer.commit()
        }

        if let textureA, textureA.width == Int(inputImage.extent.width), textureA.height == Int(inputImage.extent.height) {
            self.context.render(inputImage, to: textureA, commandBuffer: commandBuffer, bounds: inputImage.extent, colorSpace: self.context.workingColorSpace ?? CGColorSpaceCreateDeviceRGB())
            return
        }
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba16Float,
            width: Int(inputImage.extent.size.width),
            height: Int(inputImage.extent.size.height),
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite, .renderTarget]
        guard let textureA = device.makeTexture(descriptor: descriptor) else {
            throw Error.cantInstantiateTexture
        }
        context.render(inputImage, to: textureA, commandBuffer: commandBuffer, bounds: inputImage.extent, colorSpace: context.workingColorSpace ?? CGColorSpaceCreateDeviceRGB())
        self.textureA = textureA
        guard let textureB = device.makeTexture(descriptor: descriptor) else {
            throw Error.cantInstantiateTexture
        }
        self.textureB = textureB
        guard let textureC = device.makeTexture(descriptor: descriptor) else {
            throw Error.cantInstantiateTexture
        }
        self.textureC = textureC
    }
    
    private var frameNum: UInt32 = 0
    
    var outputImage: CIImage? {
        let frameNum = self.frameNum
        defer { self.frameNum += 1 }
        guard let inputImage else { return nil }
        do {
            try setup(with: inputImage)
        } catch {
            print("Error setting up texture with input image: \(error)")
            return nil
        }
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            print("Couldn't make command buffer")
            return nil
        }
        
        let textures: [MTLTexture] = [textureA, textureB, textureC]
        let iter = IteratorThing(vals: textures)
        
        do {
            try Self.convertToYIQ(
                iter.next()!,
                output: iter.next()!,
                library: library,
                commandBuffer: commandBuffer,
                device: device
            )
//            try Self.inputLuma(
//                iter.last!,
//                output: iter.next()!,
//                commandBuffer: commandBuffer,
//                lumaLowpass: effect.inputLumaFilter, 
//                lumaBoxFilter: lumaBoxFilter,
//                lumaNotchFilter: lumaNotchFilter
//            )
//            try Self.chromaLowpass(
//                iter.last!,
//                output: iter.next()!,
//                commandBuffer: commandBuffer,
//                chromaLowpass: effect.chromaLowpassIn,
//                lightFilter: lightChromaLowpassFilter,
//                fullFilter: fullChromaLowpassFilter
//            )
//            try Self.chromaIntoLuma(
//                inputTexture: iter.last!,
//                outputTexture: iter.next()!,
//                timestamp: frameNum,
//                phaseShift: effect.videoScanlinePhaseShift,
//                phaseShiftOffset: effect.videoScanlinePhaseShiftOffset,
//                filter: self.chromaIntoLumaFilter,
//                library: library,
//                device: device,
//                commandBuffer: commandBuffer
//            )
//            try Self.compositePreemphasis(
//                inputTexture: iter.last!,
//                outputTexture: iter.next()!,
//                filter: compositePreemphasisFilter,
//                commandBuffer: commandBuffer
//            )
//            try Self.compositeNoise(
//                inputTexture: iter.last!,
//                outputTexture: iter.next()!,
//                filter: compositeNoiseFilter,
//                commandBuffer: commandBuffer
//            )
//            try Self.snow(
//                inputTexture: iter.last!,
//                outputTexture: iter.next()!,
//                filter: snowFilter,
//                commandBuffer: commandBuffer
//            )
            try Self.headSwitching(
                inputTexture: iter.last!,
                outputTexture: iter.next()!,
                filter: headSwitchingFilter, 
                headSwitching: effect.headSwitching,
                commandBuffer: commandBuffer
            )
            try Self.convertToRGB(
                iter.last!,
                output: iter.next()!,
                commandBuffer: commandBuffer,
                library: library,
                device: device
            )
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
        } catch {
            print("Error generating output image: \(error)")
            return nil
        }
        let outImage = CIImage(mtlTexture: iter.last!)
        return outImage
    }
}
