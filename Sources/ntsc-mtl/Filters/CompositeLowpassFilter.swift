//
//  CompositeLowpassFilter.swift
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-06-22.
//

import Foundation
import Metal
import MetalPerformanceShaders

public class CompositeLowpassFilter {
    typealias Error = TextureFilterError
    private let device: MTLDevice
    private let pipelineCache: MetalPipelineCache
    private let iLowpassFilter: LowpassFilter
    private let qLowpassFilter: LowpassFilter
    private var iTex: MTLTexture?
    private var qTex: MTLTexture?
    
    private static let iFrequencyCutoff: Float = 1_300_000
    private static let qFrequencyCutoff: Float = 600_000
    private static let iDelay: UInt = 2
    private static let qDelay: UInt = 4
    
    
    init(device: MTLDevice, pipelineCache: MetalPipelineCache) throws {
        self.iLowpassFilter = LowpassFilter(frequencyCutoff: Self.iFrequencyCutoff, countInSeries: 3, device: device)
        self.qLowpassFilter = LowpassFilter(frequencyCutoff: Self.qFrequencyCutoff, countInSeries: 3, device: device)
        self.device = device
        self.pipelineCache = pipelineCache
    }
    
    func run(input: MTLTexture, texA: MTLTexture, texB: MTLTexture, output: MTLTexture, commandBuffer: MTLCommandBuffer) throws {
        do {
            try privateRun(input: input, iTex: texA, qTex: texB, output: output, commandBuffer: commandBuffer)
        } catch {
            print("Error in private run: \(error)")
            try justBlit(from: input, to: output, commandBuffer: commandBuffer)
        }
    }
    
    private func privateRun(
        input: MTLTexture,
        iTex: MTLTexture,
        qTex: MTLTexture,
        output: MTLTexture,
        commandBuffer: MTLCommandBuffer
    ) throws {
        iLowpassFilter.run(input: input, output: iTex, commandBuffer: commandBuffer)
        qLowpassFilter.run(input: input, output: qTex, commandBuffer: commandBuffer)
        try composeAndDelay(y: input, i: iTex, q: qTex, output: output, commandBuffer: commandBuffer)
    }
    
    private func composeAndDelay(y: MTLTexture, i: MTLTexture, q: MTLTexture, output: MTLTexture, commandBuffer: MTLCommandBuffer) throws {
        try encodeKernelFunction(.composeAndDelay, pipelineCache: pipelineCache, textureWidth: y.width, textureHeight: y.height, commandBuffer: commandBuffer, encode: { encoder in
            encoder.setTexture(y, index: 0)
            encoder.setTexture(i, index: 1)
            encoder.setTexture(q, index: 2)
            encoder.setTexture(output, index: 3)
            var iDelay = Self.iDelay
            encoder.setBytes(&iDelay, length: MemoryLayout<UInt>.size, index: 0)
            var qDelay = Self.qDelay
            encoder.setBytes(&qDelay, length: MemoryLayout<UInt>.size, index: 1)
        })
    }
}
