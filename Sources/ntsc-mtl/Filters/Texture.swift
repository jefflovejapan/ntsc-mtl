//
//  IIRTextureFilter.swift
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-06-04.
//

import Foundation
import Metal

public enum Texture {
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

