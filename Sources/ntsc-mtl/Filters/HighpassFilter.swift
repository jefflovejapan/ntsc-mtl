//
//  HighpassFilter.swift
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-06-24.
//

import Foundation
import Metal

public class HighpassFilter {
    typealias Error = TextureFilterError
    private let lowpassFilter: LowpassFilter
    private let device: MTLDevice
    private let pipelineCache: MetalPipelineCache
    var frequencyCutoff: Float {
        lowpassFilter.frequencyCutoff
    }
    
    
    init(lowpassFilter: LowpassFilter, device: MTLDevice, pipelineCache: MetalPipelineCache
    ) {
        self.lowpassFilter = lowpassFilter
        self.device = device
        self.pipelineCache = pipelineCache
    }
    
    func run(input: MTLTexture, tex: MTLTexture, output: MTLTexture, commandBuffer: MTLCommandBuffer) throws {
        lowpassFilter.run(input: input, output: tex, commandBuffer: commandBuffer)        
        try encodeKernelFunction(.highpass, pipelineCache: pipelineCache, textureWidth: input.width, textureHeight: input.height, commandBuffer: commandBuffer, encode: { encoder in
            encoder.setTexture(input, index: 0)
            encoder.setTexture(tex, index: 1)
            encoder.setTexture(output, index: 2)
        })
    }
}
