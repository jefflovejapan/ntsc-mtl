//
//  VHSLumaLowpassFitler.swift
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-06-24.
//

import Foundation
import Metal
import MetalPerformanceShaders

class VHSLumaLowpassFilter {
    typealias Error = TextureFilterError
    let frequencyCutoff: Float
    private let preLowpass: LowpassFilter
    private let tripleLowpass: LowpassFilter
    private let device: MTLDevice
    private let pipelineCache: MetalPipelineCache
    private var texA: MTLTexture?
    private var texB: MTLTexture?
    
    init(frequencyCutoff: Float, device: MTLDevice, pipelineCache: MetalPipelineCache) {
        self.frequencyCutoff = frequencyCutoff
        self.device = device
        self.pipelineCache = pipelineCache
        self.preLowpass = LowpassFilter(frequencyCutoff: frequencyCutoff, countInSeries: 1, device: device)
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
        preLowpass.run(input: input, output: texB, commandBuffer: commandBuffer)
        
        try vhsSumAndScale(input: input, triple: texA, pre: texB, output: output, commandBuffer: commandBuffer)
    }
    
    private func vhsSumAndScale(input: MTLTexture, triple: MTLTexture, pre: MTLTexture, output: MTLTexture, commandBuffer: MTLCommandBuffer) throws {
        let pipelineState = try pipelineCache.pipelineState(function: .vhsSumAndScale)
        guard let commandEncoder = commandBuffer.makeComputeCommandEncoder() else {
            throw Error.cantMakeComputeEncoder
        }
        commandEncoder.setComputePipelineState(pipelineState)
        commandEncoder.setTexture(input, index: 0)
        commandEncoder.setTexture(pre, index: 1)
        commandEncoder.setTexture(triple, index: 2)
        commandEncoder.setTexture(output, index: 3)
        commandEncoder.dispatchThreads(textureWidth: input.width, textureHeight: input.height)
        commandEncoder.endEncoding()
    }
}
