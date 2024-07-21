//
//  File.swift
//  
//
//  Created by Jeffrey Blagdon on 2024-07-02.
//

import Foundation
import Metal

public class CompositePreemphasisFilter {
    typealias Error = TextureFilterError
    private let device: MTLDevice
    private let pipelineCache: MetalPipelineCache
    private var highpassFilter: HighpassFilter
    var preemphasis: Float16 = NTSCEffect.default.compositePreemphasis
    
    init(frequencyCutoff: Float, device: MTLDevice, pipelineCache: MetalPipelineCache) {
        self.device = device
        self.pipelineCache = pipelineCache
        let lowpass = LowpassFilter(frequencyCutoff: frequencyCutoff, device: device)
        self.highpassFilter = HighpassFilter(lowpassFilter: lowpass, device: device, pipelineCache: pipelineCache)
    }
    
    func run(input: MTLTexture, texA: MTLTexture, texB: MTLTexture, output: MTLTexture, commandBuffer: MTLCommandBuffer) throws {
        let highpassed = texA
        let spare = texB
        try highpassFilter.run(input: input, tex: spare, output: highpassed, commandBuffer: commandBuffer)
        try encodeKernelFunction(.compositePreemphasis, pipelineCache: pipelineCache, textureWidth: input.width, textureHeight: input.height, commandBuffer: commandBuffer, encode: { encoder in
            encoder.setTexture(input, index: 0)
            encoder.setTexture(highpassed, index: 1)
            encoder.setTexture(output, index: 2)
            var preemphasis = preemphasis
            encoder.setBytes(&preemphasis, length: MemoryLayout<Float16>.size, index: 0)
        })
    }
}
