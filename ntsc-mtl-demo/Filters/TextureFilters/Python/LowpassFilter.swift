//
//  LowpassFilter.swift
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-06-22.
//

import Foundation
import Metal

class LowpassFilter {
    typealias Error = TextureFilterError
    let rate: Float
    let frequencyHz: Float
    private let alpha: Float16
    private let initialValue: Float16
    private let device: MTLDevice
    private let pipelineCache: MetalPipelineCache
    
    private var prev: MTLTexture?
    
    
    init(rate: Float, frequencyHz: Float, initialValue: Float16, device: MTLDevice, pipelineCache: MetalPipelineCache) throws {
        self.rate = rate
        self.frequencyHz = frequencyHz
        let timeInterval = (1.0 / rate)
        let tau = 1.0 / (frequencyHz * 2 * .pi)
        let alpha = timeInterval / (tau + timeInterval)
        self.alpha = Float16(alpha)
        self.initialValue = initialValue
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
        if let prev {
            needsUpdate = !(prev.width == input.width && prev.height == input.height)
        } else {
            needsUpdate = true
        }
        if needsUpdate {
            guard let prev = IIRTextureFilter.texture(from: input, device: device) else {
                throw Error.cantMakeTexture
            }
            try IIRTextureFilter.paint(
                texture: prev,
                with: [initialValue, initialValue, initialValue, 1],
                device: device,
                pipelineCache: pipelineCache,
                commandBuffer: commandBuffer
            )
            self.prev = prev
        }
        
        guard let prev else {
            throw Error.cantMakeTexture
        }
        
        
        /*
         From the python
         
         def lowpass(self, sample: float) -> float:
                 # stage1: input -> newTex
                 stage1 = sample * self.alpha
                 # stage2: prev -> newTex
                 stage2 = self.prev - self.prev * self.alpha
                 # stage3: (stage1, stage2) -> prev
                 self.prev = stage1 + stage2
                 # stage4: prev -> output
                 return self.prev
         
         This means that we can jump straight to the point where we set prev:
         self.prev = (sample * self.alpha) + (self.prev - self.prev * alpha)
         Save that out and return it
         */
        
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw Error.cantMakeComputeEncoder
        }
        let pipelineState = try pipelineCache.pipelineState(function: .lowpass)
        encoder.setComputePipelineState(pipelineState)
        encoder.setTexture(input, index: 0)
        encoder.setTexture(prev, index: 1)
        encoder.setTexture(output, index: 2)
        var alpha = alpha
        encoder.setBytes(&alpha, length: MemoryLayout<Float16>.size, index: 0)
        encoder.dispatchThreads(textureWidth: input.width, textureHeight: input.height)
        encoder.endEncoding()
        try justBlit(from: output, to: prev, commandBuffer: commandBuffer)
    }
}
