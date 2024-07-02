//
//  VHSLumaLowpassFitler.swift
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-06-24.
//

import Foundation
import Metal
import MetalPerformanceShaders

public class VHSLumaLowpassFilter {
    typealias Error = TextureFilterError
    let frequencyCutoff: Float
    private let preHighpass: HighpassFilter
    private let tripleLowpass: LowpassFilter
    private let device: MTLDevice
    private let pipelineCache: MetalPipelineCache
    private var texA: MTLTexture?
    private var texB: MTLTexture?
    
    init(frequencyCutoff: Float, device: MTLDevice, pipelineCache: MetalPipelineCache) {
        self.frequencyCutoff = frequencyCutoff
        self.device = device
        self.pipelineCache = pipelineCache
        let preLowpass = LowpassFilter(frequencyCutoff: frequencyCutoff, countInSeries: 1, device: device)
        self.preHighpass = HighpassFilter(
            lowpassFilter: preLowpass, device: device, pipelineCache: pipelineCache)
        self.tripleLowpass = LowpassFilter(frequencyCutoff: frequencyCutoff, countInSeries: 3, device: device)
    }
    
    func run(input: MTLTexture, output: MTLTexture, commandBuffer: MTLCommandBuffer) throws {
        let needsUpdate: Bool
        if let texA {
            needsUpdate = !(texA.width == input.width && texA.height == input.height)
        } else {
            needsUpdate = true
        }
        if needsUpdate {
            let texs = Array(Texture.textures(from: input, device: device).prefix(3))
            guard texs.count == 3 else {
                throw Error.cantMakeTexture
            }
            
            texA = texs[0]
            texB = texs[1]
        }
        guard let texA, let texB else {
            throw Error.cantMakeTexture
        }
        tripleLowpass.run(input: input, output: texA, commandBuffer: commandBuffer)
        try preHighpass.run(input: input, output: texB, commandBuffer: commandBuffer)
        try vhsSumAndScale(input: input, triple: texA, pre: texB, output: output, commandBuffer: commandBuffer)
    }
    
    private func vhsSumAndScale(input: MTLTexture, triple: MTLTexture, pre: MTLTexture, output: MTLTexture, commandBuffer: MTLCommandBuffer) throws {
        try encodeKernelFunction(.vhsSumAndScale, pipelineCache: pipelineCache, textureWidth: input.width, textureHeight: input.height, commandBuffer: commandBuffer, encode: { encoder in
            encoder.setTexture(input, index: 0)
            encoder.setTexture(pre, index: 1)
            encoder.setTexture(triple, index: 2)
            encoder.setTexture(output, index: 3)
        })
    }
}
