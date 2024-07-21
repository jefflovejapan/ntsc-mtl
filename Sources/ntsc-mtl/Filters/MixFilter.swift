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
    
    private let pipelineCache: MetalPipelineCache
    
    init(pipelineCache: MetalPipelineCache) {
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
        try encodeKernelFunction(.mix, pipelineCache: pipelineCache, textureWidth: input.width, textureHeight: input.height, commandBuffer: commandBuffer, encode: { encoder in
            encoder.setTexture(input, index: 0)
            encoder.setTexture(output, index: 1)
            var min = min
            encoder.setBytes(&min, length: MemoryLayout<Float16>.size, index: 0)
            var max = max
            encoder.setBytes(&max, length: MemoryLayout<Float16>.size, index: 1)
        })
    }
}
