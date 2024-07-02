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
    private var tex: MTLTexture?
    var preemphasis: Float16 = NTSCEffect.default.compositePreemphasis
    
    init(frequencyCutoff: Float, device: MTLDevice, pipelineCache: MetalPipelineCache) {
        self.device = device
        self.pipelineCache = pipelineCache
        let lowpass = LowpassFilter(frequencyCutoff: frequencyCutoff, device: device)
        self.highpassFilter = HighpassFilter(lowpassFilter: lowpass, device: device, pipelineCache: pipelineCache)
    }
    
    func run(input: MTLTexture, output: MTLTexture, commandBuffer: MTLCommandBuffer) throws {
        let needsUpdate: Bool
        if let tex{
            needsUpdate = !(tex.width == input.width && tex.height == input.height)
        } else {
            needsUpdate = true
        }
        if needsUpdate {
            tex = Texture.texture(from: input, device: device)
        }
        guard let tex else {
            throw Error.cantMakeTexture
        }
        try highpassFilter.run(input: input, output: tex, commandBuffer: commandBuffer)
        try encodeKernelFunction(.compositePreemphasis, pipelineCache: pipelineCache, textureWidth: input.width, textureHeight: input.height, commandBuffer: commandBuffer, encode: { encoder in
            encoder.setTexture(input, index: 0)
            encoder.setTexture(tex, index: 1)
            encoder.setTexture(output, index: 2)
            var preemphasis = preemphasis
            encoder.setBytes(&preemphasis, length: MemoryLayout<Float16>.size, index: 0)
        })
    }
}
