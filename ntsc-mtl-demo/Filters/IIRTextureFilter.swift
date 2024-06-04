//
//  IIRTextureFilter.swift
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-06-03.
//

import Foundation
import CoreImage
import Metal

class NTSCTextureFilter {
    enum Error: Swift.Error {
        case cantInstantiateTexture
    }
    
    private var texture: MTLTexture!
    private let device: MTLDevice
    private let context: CIContext
    var effect: NTSCEffect = .default
    
    init(device: MTLDevice, context: CIContext) {
        self.device = device
        self.context = context
    }
    
    var inputImage: CIImage?
    
    static func convertToYIQ(_ texture: (any MTLTexture), device: MTLDevice) {
        // Create a command buffer and encoder
          let commandQueue = device.makeCommandQueue()!
          let commandBuffer = commandQueue.makeCommandBuffer()!
          let commandEncoder = commandBuffer.makeComputeCommandEncoder()!
          
          // Set up the compute pipeline
          let defaultLibrary = device.makeDefaultLibrary()!
          let function = defaultLibrary.makeFunction(name: "convertToYIQ")!
          let pipelineState = try! device.makeComputePipelineState(function: function)
          commandEncoder.setComputePipelineState(pipelineState)
          
          // Set the texture and dispatch threads
          commandEncoder.setTexture(texture, index: 0)
          let threadGroupSize = MTLSize(width: 8, height: 8, depth: 1)
          let threadGroups = MTLSize(width: (texture.width + threadGroupSize.width - 1) / threadGroupSize.width,
                                     height: (texture.height + threadGroupSize.height - 1) / threadGroupSize.height,
                                     depth: 1)
          commandEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
          
          // Finalize encoding
          commandEncoder.endEncoding()
          commandBuffer.commit()
    }
    
    static func convertToRGB(_ texture: (any MTLTexture), device: MTLDevice) {
        // Create a command buffer and encoder
          let commandQueue = device.makeCommandQueue()!
          let commandBuffer = commandQueue.makeCommandBuffer()!
          let commandEncoder = commandBuffer.makeComputeCommandEncoder()!
          
          // Set up the compute pipeline
          let defaultLibrary = device.makeDefaultLibrary()!
          let function = defaultLibrary.makeFunction(name: "convertToRGB")!
          let pipelineState = try! device.makeComputePipelineState(function: function)
          commandEncoder.setComputePipelineState(pipelineState)
          
          // Set the texture and dispatch threads
          commandEncoder.setTexture(texture, index: 0)
          let threadGroupSize = MTLSize(width: 8, height: 8, depth: 1)
          let threadGroups = MTLSize(width: (texture.width + threadGroupSize.width - 1) / threadGroupSize.width,
                                     height: (texture.height + threadGroupSize.height - 1) / threadGroupSize.height,
                                     depth: 1)
          commandEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
          
          // Finalize encoding
          commandEncoder.endEncoding()
          commandBuffer.commit()
    }
    
    private func setup(with inputImage: CIImage) throws {
        if let texture, texture.width == Int(inputImage.extent.width), texture.height == Int(inputImage.extent.height) {
            self.context.render(inputImage, to: texture, commandBuffer: nil, bounds: inputImage.extent, colorSpace: self.context.workingColorSpace ?? CGColorSpaceCreateDeviceRGB())
            return
        }
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: Int(inputImage.extent.size.width),
            height: Int(inputImage.extent.size.height),
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite, .renderTarget]
        guard let texture = device.makeTexture(descriptor: descriptor) else {
            throw Error.cantInstantiateTexture
        }
        context.render(inputImage, to: texture, commandBuffer: nil, bounds: inputImage.extent, colorSpace: context.workingColorSpace ?? CGColorSpaceCreateDeviceRGB())
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
        Self.convertToYIQ(texture, device: self.device)
//        Self.convertToRGB(texture, device: self.device)
        return CIImage(mtlTexture: texture)
    }
}
