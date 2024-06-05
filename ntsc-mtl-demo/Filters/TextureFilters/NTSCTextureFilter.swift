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
    private var texture: MTLTexture!
    private let device: MTLDevice
    private let context: CIContext
    private let commandQueue: MTLCommandQueue
    private let library: MTLLibrary
    var effect: NTSCEffect = .default
    
    // MARK: -Filters
    private let lumaBoxFilter: LumaBoxTextureFilter
    private let lumaNotchFilter: IIRTextureFilter
    
    init(device: MTLDevice, context: CIContext) throws {
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
            channel: .y,
            scale: 1,
            delay: 0
        )
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
        let threadGroupSize = MTLSize(width: 8, height: 8, depth: 1)
        let threadGroups = MTLSize(
            width: (texture.width + threadGroupSize.width - 1) / threadGroupSize.width,
            height: (texture.height + threadGroupSize.height - 1) / threadGroupSize.height,
            depth: 1
        )
        commandEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
        
        // Finalize encoding
        commandEncoder.endEncoding()
    }
    
    static func inputLuma(
        _ texture: (any MTLTexture),
        commandBuffer: MTLCommandBuffer,
        lumaLowpass: LumaLowpass,
        lumaBoxFilter: LumaBoxTextureFilter,
        lumaNotchFilter: IIRTextureFilter
    ) throws {
        switch lumaLowpass {
        case .none:
            return
        case .box:
            try lumaBoxFilter.run(outputTexture: texture, commandBuffer: commandBuffer)
        case .notch:
            try lumaNotchFilter.run(outputTexture: texture, commandBuffer: commandBuffer)
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
        let threadGroupSize = MTLSize(width: 8, height: 8, depth: 1)
        let threadGroups = MTLSize(
            width: (texture.width + threadGroupSize.width - 1) / threadGroupSize.width,
            height: (texture.height + threadGroupSize.height - 1) / threadGroupSize.height,
            depth: 1
        )
        commandEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
        
        commandEncoder.endEncoding()
    }
    
    private func setup(with inputImage: CIImage) throws {
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            throw Error.cantMakeCommandBuffer
        }
        
        defer {
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
        }

        if let texture, texture.width == Int(inputImage.extent.width), texture.height == Int(inputImage.extent.height) {
            self.context.render(inputImage, to: texture, commandBuffer: commandBuffer, bounds: inputImage.extent, colorSpace: self.context.workingColorSpace ?? CGColorSpaceCreateDeviceRGB())
            return
        }
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba32Float,
            width: Int(inputImage.extent.size.width),
            height: Int(inputImage.extent.size.height),
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite, .renderTarget]
        guard let texture = device.makeTexture(descriptor: descriptor) else {
            throw Error.cantInstantiateTexture
        }
        context.render(inputImage, to: texture, commandBuffer: commandBuffer, bounds: inputImage.extent, colorSpace: context.workingColorSpace ?? CGColorSpaceCreateDeviceRGB())
        self.texture = texture
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
            try Self.convertToYIQ(texture, library: library, commandBuffer: commandBuffer, device: device)
            try Self.inputLuma(texture, commandBuffer: commandBuffer, lumaLowpass: effect.inputLumaFilter, lumaBoxFilter: lumaBoxFilter, lumaNotchFilter: lumaNotchFilter)
            try Self.convertToRGB(texture, commandBuffer: commandBuffer, library: library, device: device)
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
        } catch {
            print("Error converting to YIQ: \(error)")
            return nil
        }
        let outImage = CIImage(mtlTexture: texture)
        return outImage
    }
}