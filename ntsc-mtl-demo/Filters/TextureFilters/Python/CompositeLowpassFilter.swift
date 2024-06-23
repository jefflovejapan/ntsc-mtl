//
//  CompositeLowpassFilter.swift
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-06-22.
//

import Foundation
import Metal

class CompositeLowpassFilter {
    typealias Error = TextureFilterError
    private let device: MTLDevice
    private let pipelineCache: MetalPipelineCache
    
    private let iFilters: [LowpassFilter]
    private let qFilters: [LowpassFilter]
    private var textureA: MTLTexture?
    private var textureB: MTLTexture?
    private var textureC: MTLTexture?
    
    /*
     cutoff = 1300000.0 if p == 1 else 600000.0
            # "delay" meaning shifting chroma -- 2 for I and 4 for Q
            delay = 2 if (p == 1) else 4

            # operating on I if 1, Q if 2
            P = fI if (p == 1) else fQ

            # selecting every other line (don't need to do this)
            P = P[field::2]
            lp = lowpassFilters(cutoff, reset=0.0)
     
     def lowpassFilters(cutoff: float, reset: float, rate: float = Ntsc.NTSC_RATE) -> List[LowpassFilter]:
         return [LowpassFilter(rate, cutoff, reset) for x in range(0, 3)]
     cutoff = hz
     reset = value
     
     
     */
    
    private static let iFrequencyCutoff: Float = 1_300_000
    private static let qFrequencyCutoff: Float = 600_000
    private static let iDelay: UInt = 2
    private static let qDelay: UInt = 4
    
    
    init(device: MTLDevice, pipelineCache: MetalPipelineCache) throws {
        self.iFilters = try (0..<3).map { _ in
            try LowpassFilter(
                rate: NTSC.rate,
                frequencyHz: Self.iFrequencyCutoff,
                initialValue: 0,
                device: device,
                pipelineCache: pipelineCache
            )
        }
        self.qFilters = try (0..<3).map { _ in
            try LowpassFilter(
                rate: NTSC.rate,
                frequencyHz: Self.qFrequencyCutoff,
                initialValue: 0,
                device: device,
                pipelineCache: pipelineCache
            )
        }
        self.device = device
        self.pipelineCache = pipelineCache
    }
    
    func run(input: MTLTexture, output: MTLTexture, commandBuffer: MTLCommandBuffer) throws {
        do {
            try privateRun(input: input, output: output, commandBuffer: commandBuffer)
        } catch {
            print("Error in private run: \(error)")
            try justBlit(from: input, to: output, commandBuffer: commandBuffer)
        }
    }
    
    private func privateRun(
        input: MTLTexture,
        output: MTLTexture,
        commandBuffer: MTLCommandBuffer
    ) throws {
        let needsUpdate: Bool
        if let textureA {
            needsUpdate = !(textureA.width == input.width && textureA.height == input.height)
        } else {
            needsUpdate = true
        }
        if needsUpdate {
            let textures = Array(IIRTextureFilter.textures(from: input, device: device).prefix(3))
            self.textureA = textures[0]
            self.textureB = textures[1]
            self.textureC = textures[2]
        }
        
        guard let textureA, let textureB, let textureC else {
            throw Error.cantMakeTexture
        }
        
        try iFilters[0].run(input: input, output: textureA, commandBuffer: commandBuffer)
        try iFilters[1].run(input: textureA, output: textureB, commandBuffer: commandBuffer)
        try iFilters[2].run(input: textureB, output: textureA, commandBuffer: commandBuffer)
        let i = textureA
        
        try qFilters[0].run(input: input, output: textureB, commandBuffer: commandBuffer)
        try qFilters[1].run(input: textureB, output: textureC, commandBuffer: commandBuffer)
        try qFilters[2].run(input: textureC, output: textureB, commandBuffer: commandBuffer)
        let q = textureB
        try composeAndDelay(y: input, i: textureA, q: textureB, output: output, commandBuffer: commandBuffer)
    }
    
    private func composeAndDelay(y: MTLTexture, i: MTLTexture, q: MTLTexture, output: MTLTexture, commandBuffer: MTLCommandBuffer) throws {
        let pipelineState = try pipelineCache.pipelineState(function: .composeAndDelay)
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw Error.cantMakeComputeEncoder
        }
        encoder.setComputePipelineState(pipelineState)
        encoder.setTexture(y, index: 0)
        encoder.setTexture(i, index: 1)
        encoder.setTexture(q, index: 2)
        encoder.setTexture(output, index: 3)
        var iDelay = Self.iDelay
        encoder.setBytes(&iDelay, length: MemoryLayout<UInt>.size, index: 0)
        var qDelay = Self.qDelay
        encoder.setBytes(&qDelay, length: MemoryLayout<UInt>.size, index: 0)
        encoder.dispatchThreads(textureWidth: y.width, textureHeight: y.height)
        encoder.endEncoding()
    }
}
