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
    case cantMakeCommandEncoder
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
    }
    
    var inputImage: CIImage?
    
    static func convertToYIQ(_ texture: (any MTLTexture), commandQueue: MTLCommandQueue, library: MTLLibrary, device: MTLDevice) throws {
        // Create a command buffer and encoder
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            throw Error.cantMakeCommandBuffer
        }
        guard let commandEncoder = commandBuffer.makeComputeCommandEncoder() else {
            throw Error.cantMakeCommandEncoder
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
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }
    
    static func inputLuma(_ texture: (any MTLTexture), commandQueue: MTLCommandQueue, library: MTLLibrary, device: MTLDevice, lumaLowpass: LumaLowpass, lumaBoxFilter: LumaBoxTextureFilter) throws {
        switch lumaLowpass {
        case .none:
            return
        case .box:
            try lumaBoxFilter.run(outputTexture: texture)
        case .notch:
            try Self.inputLumaNotch(texture, commandQueue: commandQueue, library: library, device: device)
        }
    }
    
    static func inputLumaNotch(_ texture: (any MTLTexture), commandQueue: MTLCommandQueue, library: MTLLibrary, device: MTLDevice) throws {
        fatalError("Not implemented")
    }
    
    static func convertToRGB(_ texture: (any MTLTexture), commandQueue: MTLCommandQueue, library: MTLLibrary, device: MTLDevice) throws {
        // Create a command buffer and encoder
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            throw Error.cantMakeCommandBuffer
        }
        guard let commandEncoder = commandBuffer.makeComputeCommandEncoder() else {
            throw Error.cantMakeCommandEncoder
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
        
        // Finalize encoding
        commandEncoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
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
        do {
            try Self.convertToYIQ(texture, commandQueue: commandQueue, library: library, device: device)
            try Self.inputLuma(texture, commandQueue: commandQueue, library: library, device: device, lumaLowpass: effect.inputLumaFilter, lumaBoxFilter: lumaBoxFilter)
            try Self.convertToRGB(texture, commandQueue: commandQueue, library: library, device: device)
        } catch {
            print("Error converting to YIQ: \(error)")
            return nil
        }
        let outImage = CIImage(mtlTexture: texture)
        return outImage
    }
}
