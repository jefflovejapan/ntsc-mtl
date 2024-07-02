//
//  EncodeKernelFunction.swift
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-06-24.
//

import Foundation
import Metal

func encodeKernelFunction(_ kernelFunction: KernelFunction, pipelineCache: MetalPipelineCache, textureWidth: Int, textureHeight: Int, commandBuffer: MTLCommandBuffer, encode: (MTLComputeCommandEncoder) -> Void) throws {
    let pipelineState = try pipelineCache.pipelineState(function: kernelFunction)
    guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
        throw TextureFilterError.cantMakeComputeEncoder
    }
    
    encoder.setComputePipelineState(pipelineState)
    encode(encoder)
    encoder.dispatchThreads(textureWidth: textureWidth, textureHeight: textureHeight)
    encoder.endEncoding()
}
