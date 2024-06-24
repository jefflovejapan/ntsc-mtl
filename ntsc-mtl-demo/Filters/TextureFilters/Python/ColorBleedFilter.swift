//
//  ColorBleedFilter.swift
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-06-22.
//

import Foundation
import Metal

class ColorBleedFilter {
    typealias Error = TextureFilterError
    
    let device: MTLDevice
    let pipelineCache: MetalPipelineCache
    
    var xOffset: Int = Int(NTSCEffect.default.colorBleedXOffset)
    var yOffset: Int = Int(NTSCEffect.default.colorBleedYOffset)
    
    init(device: MTLDevice, pipelineCache: MetalPipelineCache) {
        self.device = device
        self.pipelineCache = pipelineCache
    }
    
    func run(input: MTLTexture, output: MTLTexture, commandBuffer: MTLCommandBuffer) throws {
        try encodeKernelFunction(.colorBleed, pipelineCache: pipelineCache, textureWidth: input.width, textureHeight: input.height, commandBuffer: commandBuffer, encode: { encoder in
            encoder.setTexture(input, index: 0)
            encoder.setTexture(output, index: 1)
            var xOffset = xOffset
            encoder.setBytes(&xOffset, length: MemoryLayout<Int>.size, index: 0)
            var yOffset = yOffset
            encoder.setBytes(&yOffset, length: MemoryLayout<Int>.size, index: 1)
        })
    }
}
