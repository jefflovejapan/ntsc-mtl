//
//  HeadSwitchingFilter.swift
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-06-25.
//

import Foundation
import Metal
import CoreImage
import CoreImage.CIFilterBuiltins

public class HeadSwitchingFilter {
    typealias Error = TextureFilterError
    var phaseNoise: Float16 = NTSCEffect.default.headSwitchingPhaseNoise
    var headSwitchingPoint: Float16 = NTSCEffect.default.headSwitchingPoint
    var outputNTSC: Bool = NTSCEffect.default.outputNTSC
    var headSwitchingPhase: Float16 = NTSCEffect.default.headSwitchingPhase
    var headSwitchingSpeed: Float16 = NTSCEffect.default.headSwitchingSpeed
    var frameNum: UInt32 = 0
    private let device: MTLDevice
    private let pipelineCache: MetalPipelineCache
    private let ciContext: CIContext
    
    init(device: MTLDevice, pipelineCache: MetalPipelineCache, ciContext: CIContext) {
        self.device = device
        self.pipelineCache = pipelineCache
        self.ciContext = ciContext
    }
    
    func run(input: MTLTexture, tex: MTLTexture, output: MTLTexture, commandBuffer: MTLCommandBuffer) throws {
        do {
            try privateRun(input: input, tex: tex, output: output, commandBuffer: commandBuffer)
        } catch {
            print("Error in head switching: \(error)")
            try justBlit(from: input, to: output, commandBuffer: commandBuffer)
        }
    }
    
    private let randomGenerator = CIFilter.randomGenerator()
    private var rng = SystemRandomNumberGenerator()
    
    private func deriveNoise() -> Float16 {
        let x = Int32.random(in: 1 ..< 2_000_000_000)
        let noise: Float32 = ((Float32(x) / 1000000000.0) - 1.0) * Float32(phaseNoise)
        return Float16(noise)
    }
    
    private func privateRun(input: MTLTexture, tex: MTLTexture, output: MTLTexture, commandBuffer: MTLCommandBuffer) throws {
        let randomX: UInt = rng.next(upperBound: 200)
        let randomY: UInt = rng.next(upperBound: 200)
            
        guard let randomImg: CIImage = randomGenerator.image(size: CGSize(width: input.width, height: input.height), offset: CGSize(width: CGFloat(randomX), height: CGFloat(randomY))) else {
            throw Error.cantMakeRandomImage
        }
        
        ciContext.render(randomImg, to: tex, commandBuffer: commandBuffer, bounds: randomImg.extent, colorSpace: ciContext.workingColorSpace ?? CGColorSpaceCreateDeviceRGB())
        
        try encodeKernelFunction(.headSwitching, pipelineCache: pipelineCache, textureWidth: input.width, textureHeight: input.height, commandBuffer: commandBuffer, encode: { encoder in
            encoder.setTexture(input, index: 0)
            encoder.setTexture(tex, index: 1)
            encoder.setTexture(output, index: 2)
            var frameNum = frameNum
            encoder.setBytes(&frameNum, length: MemoryLayout<UInt32>.size, index: 0)
            var headSwitchingSpeed = headSwitchingSpeed
            encoder.setBytes(&headSwitchingSpeed, length: MemoryLayout<Float16>.size, index: 1)
            var noise: Float16 = deriveNoise()
            encoder.setBytes(&noise, length: MemoryLayout<Float16>.size, index: 2)
        })
    }
}
