//
//  EmulateVHSFilter.swift
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-06-23.
//

import Foundation
import CoreImage
import Metal
import CoreImage.CIFilterBuiltins

class EmulateVHSFilter {
    typealias Error = TextureFilterError
    let tapeSpeed: VHSSpeed
    var edgeWave: UInt = UInt(NTSCEffect.default.vhsEdgeWave)
    private let mixFilter: MixFilter
    private let lumaLowpassFilter: VHSLumaLowpassFilter
    private let randomGenerator = CIFilter.randomGenerator()
    private var rng = SystemRandomNumberGenerator()
    private let device: MTLDevice
    private let pipelineCache: MetalPipelineCache
    private let ciContext: CIContext
    private var texA: MTLTexture?
    private var texB: MTLTexture?
    private var texC: MTLTexture?
    private var lowpassFilter: LowpassFilter
    
    init(tapeSpeed: VHSSpeed, device: MTLDevice, pipelineCache: MetalPipelineCache, ciContext: CIContext) {
        self.tapeSpeed = tapeSpeed
        self.device = device
        self.pipelineCache = pipelineCache
        self.ciContext = ciContext
        self.mixFilter = MixFilter(device: device, pipelineCache: pipelineCache)
        self.lowpassFilter = LowpassFilter(frequencyCutoff: tapeSpeed.lumaCut, countInSeries: 3, device: device)
        self.lumaLowpassFilter = VHSLumaLowpassFilter(frequencyCutoff: tapeSpeed.lumaCut, device: device, pipelineCache: pipelineCache)
    }
    
    func run(input: MTLTexture, output: MTLTexture, commandBuffer: MTLCommandBuffer) throws {
        do {
            try privateRun(input: input, output: output, commandBuffer: commandBuffer)
        } catch {
            print("Error in private run: \(error)")
            try justBlit(from: input, to: output, commandBuffer: commandBuffer)
        }
    }
    
    private func privateRun(input: MTLTexture, output: MTLTexture, commandBuffer: MTLCommandBuffer) throws {
        let needsTextureUpdate: Bool
        if let texA {
            needsTextureUpdate = !(texA.width == input.width || texA.height == input.height)
        } else {
            needsTextureUpdate = true
        }
        if needsTextureUpdate {
            let texs = Array(Texture.textures(from: input, device: device).prefix(3))
            guard texs.count == 3 else {
                throw Error.cantMakeTexture
            }
            self.texA = texs[0]
            self.texB = texs[1]
            self.texC = texs[2]
        }
        
        guard let texA, let texB, let texC else {
            throw Error.cantMakeTexture
        }
        
        let iter = IteratorThing(vals: [texA, texB, texC])
        
        try writeRandom(to: try iter.next(), commandBuffer: commandBuffer)
        try mixRandom(from: try iter.last, to: try iter.next(), commandBuffer: commandBuffer)
        lowpassFilter.run(input: try iter.last, output: try iter.next(), commandBuffer: commandBuffer)
        try edgeWave(input: input, random: try iter.last, output: try iter.next(), commandBuffer: commandBuffer)
        
        // updates Y
        try lumaLowpass(input: try iter.last, output: try iter.next(), filter: lumaLowpassFilter, commandBuffer: commandBuffer)
        // updates I and Q
        try chromaLowpass(input: try iter.last, output: try iter.next(), commandBuffer: commandBuffer)
        
        try chromaVertBlend(input: try iter.last, output: try iter.next(), commandBuffer: commandBuffer)
        
        try sharpen(input: try iter.last, output: try iter.next(), commandBuffer: commandBuffer)
        try chromaIntoLuma(input: try iter.last, output: try iter.next(), commandBuffer: commandBuffer)
        try chromaFromLuma(input: try iter.last, output: try iter.next(), commandBuffer: commandBuffer)
        
    }
    
    private func writeRandom(to texture: MTLTexture, commandBuffer: MTLCommandBuffer) throws {
        let randomX: UInt = rng.next(upperBound: 200)
        let randomY: UInt = rng.next(upperBound: 200)
        
        guard let randomImg = randomGenerator
            .outputImage?
            .transformed(
                by: CGAffineTransform(
                    translationX: CGFloat(randomX),
                    y: CGFloat(randomY)
                )
            )
                .cropped(
                    to: CGRect(
                        origin: .zero,
                        size: CGSize(
                            width: texture.width,
                            height: texture.height
                        )
                    )
                ) else {
            throw Error.cantMakeRandomImage
        }
        
        ciContext.render(randomImg, to: texture, commandBuffer: commandBuffer, bounds: randomImg.extent, colorSpace: ciContext.workingColorSpace ?? CGColorSpaceCreateDeviceRGB())
    }
    
    private func mixRandom(from input: MTLTexture, to output: MTLTexture, commandBuffer: MTLCommandBuffer) throws {
        mixFilter.min = 0
        mixFilter.max = Float16(edgeWave)
        try mixFilter.run(input: input, output: output, commandBuffer: commandBuffer)
    }
    
    private func edgeWave(input: MTLTexture, random: MTLTexture, output: MTLTexture, commandBuffer: MTLCommandBuffer) throws {
        let pipelineState = try pipelineCache.pipelineState(function: .vhsEdgeWave)
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw Error.cantMakeComputeEncoder
        }
        encoder.setComputePipelineState(pipelineState)
        encoder.setTexture(input, index: 0)
        encoder.setTexture(random, index: 1)
        encoder.setTexture(output, index: 2)
        var edgeWave = edgeWave
        encoder.setBytes(&edgeWave, length: MemoryLayout<UInt>.size, index: 0)
        encoder.dispatchThreads(
            textureWidth: input.width,
            textureHeight: input.height
        )
        encoder.endEncoding()
    }
    
    private func lumaLowpass(input: MTLTexture, output: MTLTexture, filter: VHSLumaLowpassFilter, commandBuffer: MTLCommandBuffer) throws {
        try filter.run(input: input, output: output, commandBuffer: commandBuffer)
    }
    
    func chromaLowpass(input: MTLTexture, output: MTLTexture, commandBuffer: MTLCommandBuffer) throws {
        try justBlit(from: input, to: output, commandBuffer: commandBuffer)
    }
    func chromaVertBlend(input: MTLTexture, output: MTLTexture, commandBuffer: MTLCommandBuffer) throws {
        try justBlit(from: input, to: output, commandBuffer: commandBuffer)
    }
    func sharpen(input: MTLTexture, output: MTLTexture, commandBuffer: MTLCommandBuffer) throws {
        try justBlit(from: input, to: output, commandBuffer: commandBuffer)
    }
    func chromaIntoLuma(input: MTLTexture, output: MTLTexture, commandBuffer: MTLCommandBuffer) throws {
        try justBlit(from: input, to: output, commandBuffer: commandBuffer)
    }
    func chromaFromLuma(input: MTLTexture, output: MTLTexture, commandBuffer: MTLCommandBuffer) throws {
        try justBlit(from: input, to: output, commandBuffer: commandBuffer)
    }
}