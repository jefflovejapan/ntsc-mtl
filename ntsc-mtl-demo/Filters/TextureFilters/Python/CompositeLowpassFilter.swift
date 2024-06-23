//
//  CompositeLowpassFilter.swift
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-06-22.
//

import Foundation
import Metal
import MetalPerformanceShaders

class CompositeLowpassFilter {
    typealias Error = TextureFilterError
    private let device: MTLDevice
    private let pipelineCache: MetalPipelineCache
    private let iBlurShader: MPSImageGaussianBlur
    private let qBlurShader: MPSImageGaussianBlur
    private var iTex: MTLTexture?
    private var qTex: MTLTexture?
    
    private static let iFrequencyCutoff: Float = 1_300_000
    private static let qFrequencyCutoff: Float = 600_000
    private static let iDelay: UInt = 2
    private static let qDelay: UInt = 4
    
    
    init(device: MTLDevice, pipelineCache: MetalPipelineCache) throws {
        /*
         ntsc-qt uses a lowpass filter with the frequency cutoffs above for i and q
         These sigma values correspond to sampling frequency / 2 * pi * cutoff
         Applying it three (n) times in succession is equivalent to multiplying sigma by sqrt(3) (sqrt(n))
         */
        self.iBlurShader = MPSImageGaussianBlur(device: device, sigma: sqrtf(3) * NTSC.rate / (2 * .pi * Self.iFrequencyCutoff))
        self.qBlurShader = MPSImageGaussianBlur(device: device, sigma: sqrtf(3) * (NTSC.rate / (2 * .pi * Self.qFrequencyCutoff)))
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
        if let iTex {
            needsUpdate = !(iTex.width == input.width && iTex.height == input.height)
        } else {
            needsUpdate = true
        }
        if needsUpdate {
            let textures = Array(IIRTextureFilter.textures(from: input, device: device).prefix(2))
            self.iTex = textures[0]
            self.qTex = textures[1]
        }
        
        guard let iTex, let qTex else {
            throw Error.cantMakeTexture
        }
        
        iBlurShader.encode(commandBuffer: commandBuffer, sourceTexture: input, destinationTexture: iTex)
        qBlurShader.encode(commandBuffer: commandBuffer, sourceTexture: input, destinationTexture: qTex)
        try composeAndDelay(y: input, i: iTex, q: qTex, output: output, commandBuffer: commandBuffer)
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
