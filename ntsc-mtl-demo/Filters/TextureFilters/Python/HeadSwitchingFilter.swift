//
//  HeadSwitchingFilter.swift
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-06-25.
//

import Foundation
import Metal

class HeadSwitchingFilter {
    private let device: MTLDevice
    private let pipelineCache: MetalPipelineCache
    
    init(device: MTLDevice, pipelineCache: MetalPipelineCache) {
        self.device = device
        self.pipelineCache = pipelineCache
    }
    
    func run(input: MTLTexture, output: MTLTexture, commandBuffer: MTLCommandBuffer) throws {
        try justBlit(from: input, to: output, commandBuffer: commandBuffer)
    }
}
