//
//  ChromaDelayTextureFilter.swift
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-06-12.
//

import Foundation
import Metal
import CoreImage
import CoreImage.CIFilterBuiltins

class ChromaDelayTextureFilter {
    typealias Error = TextureFilterError
    private let device: MTLDevice
    private let pipelineCache: MetalPipelineCache
    var chromaDelay: (Float16, Int) = NTSCEffect.default.chromaDelay
    
    init(device: MTLDevice, pipelineCache: MetalPipelineCache) {
        self.device = device
        self.pipelineCache = pipelineCache
    }
    func run(inputTexture: MTLTexture, outputTexture: MTLTexture, commandBuffer: MTLCommandBuffer) throws {
        let pipelineState: MTLComputePipelineState = try pipelineCache.pipelineState(function: .chromaDelay)
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw Error.cantMakeComputeEncoder
        }
        encoder.setComputePipelineState(pipelineState)
        encoder.setTexture(inputTexture, index: 0)
        encoder.setTexture(outputTexture, index: 1)
        var horizShift = chromaDelay.0
        encoder.setBytes(&horizShift, length: MemoryLayout<Float16>.size, index: 0)
        var vertShift = chromaDelay.1
        encoder.setBytes(&vertShift, length: MemoryLayout<Int>.size, index: 1)
        encoder.dispatchThreads(textureWidth: inputTexture.width, textureHeight: inputTexture.height)
        encoder.endEncoding()
    }
}

