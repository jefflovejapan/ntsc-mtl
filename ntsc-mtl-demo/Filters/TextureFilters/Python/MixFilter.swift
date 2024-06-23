//
//  MixFilter.swift
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-06-23.
//

import Foundation
import Metal

class MixFilter {
    typealias Error = TextureFilterError
    var min: Float16 = 0
    var max: Float16 = 1
    
    private let device: MTLDevice
    private let pipelineCache: MetalPipelineCache
    
    init(device: MTLDevice, pipelineCache: MetalPipelineCache) {
        self.device = device
        self.pipelineCache = pipelineCache
    }
    
    func run(input: MTLTexture, output: MTLTexture, commandBuffer: MTLCommandBuffer) throws {
        do {
            try privateRun(input: input, output: output, commandBuffer: commandBuffer)
        } catch {
            print("Error in mixFilter: \(error)")
            try justBlit(from: input, to: output, commandBuffer: commandBuffer)
        }
    }
    
    private func privateRun(input: MTLTexture, output: MTLTexture, commandBuffer: MTLCommandBuffer) throws {
        let pipelineState = try pipelineCache.pipelineState(function: .mix)
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw Error.cantMakeComputeEncoder
        }
        encoder.setComputePipelineState(pipelineState)
        encoder.setTexture(input, index: 0)
        encoder.setTexture(output, index: 1)
        var min = min
        encoder.setBytes(&min, length: MemoryLayout<Float16>.size, index: 0)
        var max = max
        encoder.setBytes(&max, length: MemoryLayout<Float16>.size, index: 1)
        encoder.dispatchThreads(textureWidth: input.width, textureHeight: input.height)
        encoder.endEncoding()
    }
}
