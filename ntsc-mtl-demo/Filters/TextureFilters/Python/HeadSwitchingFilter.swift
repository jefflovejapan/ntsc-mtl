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

class HeadSwitchingFilter {
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
    private var tex: MTLTexture?
    
    init(device: MTLDevice, pipelineCache: MetalPipelineCache, ciContext: CIContext) {
        self.device = device
        self.pipelineCache = pipelineCache
        self.ciContext = ciContext
    }
    
    func run(input: MTLTexture, output: MTLTexture, commandBuffer: MTLCommandBuffer) throws {
        do {
            try privateRun(input: input, output: output, commandBuffer: commandBuffer)
        } catch {
            print("Error in head switching: \(error)")
            try justBlit(from: input, to: output, commandBuffer: commandBuffer)
        }
    }
    
    private let randomGenerator = CIFilter.randomGenerator()
    private var rng = SystemRandomNumberGenerator()
    
    private func privateRun(input: MTLTexture, output: MTLTexture, commandBuffer: MTLCommandBuffer) throws {
        let needsUpdate: Bool
        if let tex {
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
            var tScaleFactor: Float16 = outputNTSC ? 262.5 : 312.5
            encoder.setBytes(&tScaleFactor, length: MemoryLayout<Float16>.size, index: 2)
//            var phaseNoise = phaseNoise
//            encoder.setBytes(&phaseNoise, length: MemoryLayout<Float16>.size, index: 0)
//            var headSwitchingPoint = headSwitchingPoint
//            encoder.setBytes(&headSwitchingPoint, length: MemoryLayout<Float16>.size, index: 1)
//            var headSwitchingPhase = headSwitchingPhase
//            encoder.setBytes(&headSwitchingPhase, length: MemoryLayout<Float16>.size, index: 3)
//            var yOffset: UInt = outputNTSC ? (262 - 240) * 2 : (312 - 288) * 2
//            encoder.setBytes(&yOffset, length: MemoryLayout<UInt>.size, index: 6)
        })
    }
}
