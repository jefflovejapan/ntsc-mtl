//
//  PhaseErrorTextureFilter.swift
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-06-12.
//

import Foundation
import Metal

class PhaseErrorTextureFilter {
    typealias Error = TextureFilterError
    private let device: MTLDevice
    private let pipelineCache: MetalPipelineCache
    var intensity: Float16 = NTSCEffect.default.chromaPhaseError
    
    init(device: MTLDevice, pipelineCache: MetalPipelineCache) {
        self.device = device
        self.pipelineCache = pipelineCache
    }
    var phaseError: Float16 = 0
    func run(inputTexture: MTLTexture, outputTexture: MTLTexture, commandBuffer: MTLCommandBuffer) throws {
        let pipelineState: MTLComputePipelineState = try pipelineCache.pipelineState(function: .chromaPhaseOffset)
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw Error.cantMakeComputeEncoder
        }
        encoder.setComputePipelineState(pipelineState)
        encoder.setTexture(inputTexture, index: 0)
        encoder.setTexture(outputTexture, index: 1)
        var intensity = intensity
        encoder.setBytes(&intensity, length: MemoryLayout<Float16>.size, index: 0)
        encoder.dispatchThreads(textureWidth: inputTexture.width, textureHeight: inputTexture.height)
        encoder.endEncoding()
    }
}
