//
//  VHSSharpenLowpassFilter.swift
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-06-24.
//

import Foundation
import Metal
import MetalPerformanceShaders

public class VHSSharpenLowpassFilter {
    typealias Error = TextureFilterError
    let frequencyCutoff: Float
    let sharpening: Float16
    private let device: MTLDevice
    private let pipelineCache: MetalPipelineCache
    private let tripleLowpass: LowpassFilter
    
    init(frequencyCutoff: Float, sharpening: Float16, device: MTLDevice, pipelineCache: MetalPipelineCache) {
        self.frequencyCutoff = frequencyCutoff
        self.sharpening = sharpening
        self.device = device
        self.pipelineCache = pipelineCache
        self.tripleLowpass = LowpassFilter(frequencyCutoff: frequencyCutoff, countInSeries: 3, device: device)
    }
    
    func run(input: MTLTexture, tex: MTLTexture, output: MTLTexture, commandBuffer: MTLCommandBuffer) throws {
        tripleLowpass.run(input: input, output: tex, commandBuffer: commandBuffer)
        try vhsSharpen(input: input, lowpassed: tex, output: output, commandBuffer: commandBuffer)
    }
    
    private func vhsSharpen(input: MTLTexture, lowpassed: MTLTexture, output: MTLTexture, commandBuffer: MTLCommandBuffer) throws {
        try encodeKernelFunction(.vhsSharpen, pipelineCache: pipelineCache, textureWidth: input.width, textureHeight: input.height, commandBuffer: commandBuffer, encode: { encoder in
            encoder.setTexture(input, index: 0)
            encoder.setTexture(lowpassed, index: 1)
            encoder.setTexture(output, index: 2)
            var sharpening = sharpening
            encoder.setBytes(&sharpening, length: MemoryLayout<Float16>.size, index: 0)
        })
    }
}
