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
    case cantMakeFunction(String)
    case cantMakeBlitEncoder
    case logicHole(String)
}

class NTSCTextureFilter {
    typealias Error = TextureFilterError
    private var textureA: MTLTexture!
    private var textureB: MTLTexture!
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
    }
    
    var inputImage: CIImage?
    
    static func convertToYIQ(_ texture: (any MTLTexture), library: MTLLibrary, commandBuffer: MTLCommandBuffer, device: MTLDevice) throws {
        // Create a command buffer and encoder
        guard let commandEncoder = commandBuffer.makeComputeCommandEncoder() else {
            throw Error.cantMakeComputeEncoder
        }
        
        // Set up the compute pipeline
        let functionName = "convertToYIQ"
        guard let function = library.makeFunction(name: functionName) else {
            throw Error.cantMakeFunction(functionName)
        }
        let pipelineState = try device.makeComputePipelineState(function: function)
        commandEncoder.setComputePipelineState(pipelineState)
        
        // Set the texture and dispatch threads
        commandEncoder.setTexture(texture, index: 0)
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
    
    static func convertToRGB(_ texture: (any MTLTexture), commandBuffer: MTLCommandBuffer, library: MTLLibrary, device: MTLDevice) throws {
        // Create a command buffer and encoder
        guard let commandEncoder = commandBuffer.makeComputeCommandEncoder() else {
            throw Error.cantMakeComputeEncoder
        }
        
        // Set up the compute pipeline
        let functionName = "convertToRGB"
        guard let function = library.makeFunction(name: functionName) else {
            throw Error.cantMakeFunction(functionName)
        }
        let pipelineState = try device.makeComputePipelineState(function: function)
        commandEncoder.setComputePipelineState(pipelineState)
        
        // Set the texture and dispatch threads
        commandEncoder.setTexture(texture, index: 0)
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
            pixelFormat: .rgba32Float,
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
    }
    
    var outputImage: CIImage? {
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
        do {
            try Self.convertToYIQ(textureA, library: library, commandBuffer: commandBuffer, device: device)
            try Self.chromaLowpass(
                textureA,
                output: textureB,
                commandBuffer: commandBuffer,
                chromaLowpass: effect.chromaLowpassIn,
                lightFilter: lightChromaLowpassFilter,
                fullFilter: fullChromaLowpassFilter
            )
            try Self.convertToRGB(textureB, commandBuffer: commandBuffer, library: library, device: device)
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
        } catch {
            print("Error converting to YIQ: \(error)")
            return nil
        }
        let outImage = CIImage(mtlTexture: textureB)
        return outImage
    }
}
