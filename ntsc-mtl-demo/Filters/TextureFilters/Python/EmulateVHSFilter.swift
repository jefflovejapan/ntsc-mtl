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
    var lowpassCutoff: Float = NTSCEffect.default.vhsTapeSpeed.lumaCut
    var edgeWave: UInt = UInt(NTSCEffect.default.vhsEdgeWave)
    private let mixFilter: MixFilter
    private let randomGenerator = CIFilter.randomGenerator()
    private var rng = SystemRandomNumberGenerator()
    private let device: MTLDevice
    private let pipelineCache: MetalPipelineCache
    private let ciContext: CIContext
    private var texA: MTLTexture?
    private var texB: MTLTexture?
    private var texC: MTLTexture?
    private var lowpassFilter: LowpassFilter?
    
    init(device: MTLDevice, pipelineCache: MetalPipelineCache, ciContext: CIContext) {
        self.device = device
        self.pipelineCache = pipelineCache
        self.ciContext = ciContext
        self.mixFilter = MixFilter(device: device, pipelineCache: pipelineCache)
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
            let texs = Array(IIRTextureFilter.textures(from: input, device: device).prefix(2))
            guard texs.count == 2 else {
                throw Error.cantMakeTexture
            }
            self.texA = texs[0]
            self.texB = texs[1]
        }
        let needsLowpassUpdate: Bool
        if let lowpassFilter {
            needsLowpassUpdate = lowpassFilter.frequencyHz != lowpassCutoff
        } else {
            needsLowpassUpdate = true
        }
        
        if needsLowpassUpdate {
            lowpassFilter = try LowpassFilter(
                rate: NTSC.rate,
                frequencyHz: lowpassCutoff,
                initialValue: 0, 
                device: device,
                pipelineCache: pipelineCache
            )
        }
        guard let lowpassFilter else {
            throw Error.cantMakeFilter(String(describing: LowpassFilter.self))
        }
        
        guard let texA, let texB else {
            throw Error.cantMakeTexture
        }
        
        try writeRandom(to: texA, commandBuffer: commandBuffer)
        try mixRandom(from: texA, to: texB, commandBuffer: commandBuffer)
        try lowpassFilter.run(input: texB, output: texA, commandBuffer: commandBuffer)
        try edgeWave(input: input, random: texA, output: output, commandBuffer: commandBuffer)
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

}
