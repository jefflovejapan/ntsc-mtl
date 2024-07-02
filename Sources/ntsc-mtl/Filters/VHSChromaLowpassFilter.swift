//
//  VHSChromaLowpassFilter.swift
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-06-24.
//

import Foundation
import Metal
import MetalPerformanceShaders

public class VHSChromaLowpassFilter {
    typealias Error = TextureFilterError
    let frequencyCutoff: Float
    let chromaDelay: UInt
    private let tripleLowpass: LowpassFilter
    private let device: MTLDevice
    private let pipelineCache: MetalPipelineCache
    private var texA: MTLTexture?
    private var texB: MTLTexture?
    
    init(frequencyCutoff: Float, chromaDelay: UInt, device: MTLDevice, pipelineCache: MetalPipelineCache) {
        self.frequencyCutoff = frequencyCutoff
        self.chromaDelay = chromaDelay
        self.device = device
        self.pipelineCache = pipelineCache
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
            guard let tex = Texture.texture(from: input, device: device) else {
                throw Error.cantMakeTexture
            }
            
            texA = tex
        }
        guard let texA else {
            throw Error.cantMakeTexture
        }
        tripleLowpass.run(input: input, output: texA, commandBuffer: commandBuffer)
        try vhsComposeAndDelay(input: input, lowpassed: texA, output: output, commandBuffer: commandBuffer)
    }
    
    private func vhsComposeAndDelay(input: MTLTexture, lowpassed: MTLTexture, output: MTLTexture, commandBuffer: MTLCommandBuffer) throws {
        try encodeKernelFunction(.vhsComposeAndDelay, pipelineCache: pipelineCache, textureWidth: input.width, textureHeight: input.height, commandBuffer: commandBuffer, encode: { encoder in
            encoder.setTexture(input, index: 0)
            encoder.setTexture(lowpassed, index: 1)
            encoder.setTexture(output, index: 2)
            var delay = chromaDelay
            encoder.setBytes(&delay, length: MemoryLayout<UInt>.size, index: 0)
        })
    }
    
    private func vhsSumAndScale(input: MTLTexture, triple: MTLTexture, pre: MTLTexture, output: MTLTexture, commandBuffer: MTLCommandBuffer) throws {
        try encodeKernelFunction(.vhsSumAndScale, pipelineCache: pipelineCache, textureWidth: input.width, textureHeight: input.height, commandBuffer: commandBuffer, encode: {
            encoder in
            encoder.setTexture(input, index: 0)
            encoder.setTexture(pre, index: 1)
            encoder.setTexture(triple, index: 2)
            encoder.setTexture(output, index: 3)
        })
    }
}
