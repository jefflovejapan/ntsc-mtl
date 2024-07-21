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

public class EmulateVHSFilter {
    typealias Error = TextureFilterError
    let tapeSpeed: VHSSpeed
    let sharpening: Float16
    var edgeWave: UInt = UInt(NTSCEffect.default.vhsEdgeWave)
    var phaseShift: ScanlinePhaseShift
    var phaseShiftOffset: Int
    var subcarrierAmplitude: Float16
    var chromaVertBlend: Bool
    var sVideoOut: Bool
    var outputNTSC: Bool
    private let randomGenerator = CIFilter.randomGenerator()
    private var rng = SystemRandomNumberGenerator()
    private let pipelineCache: MetalPipelineCache
    private let ciContext: CIContext
    private let lowpassFilter: LowpassFilter
    private let mixFilter: MixFilter
    private let lumaLowpassFilter: VHSLumaLowpassFilter
    private let chromaLowpassFilter: VHSChromaLowpassFilter
    private let sharpenLowpassFilter: VHSSharpenLowpassFilter
    
    init(tapeSpeed: VHSSpeed, sharpening: Float16, phaseShift: ScanlinePhaseShift, phaseShiftOffset: Int, subcarrierAmplitude: Float16, chromaVertBlend: Bool, sVideoOut: Bool, outputNTSC: Bool, device: MTLDevice, pipelineCache: MetalPipelineCache, ciContext: CIContext) {
        self.tapeSpeed = tapeSpeed
        self.sharpening = sharpening
        self.phaseShift = phaseShift
        self.phaseShiftOffset = phaseShiftOffset
        self.subcarrierAmplitude = subcarrierAmplitude
        self.chromaVertBlend = chromaVertBlend
        self.sVideoOut = sVideoOut
        self.outputNTSC = outputNTSC
        self.pipelineCache = pipelineCache
        self.ciContext = ciContext
        self.mixFilter = MixFilter(pipelineCache: pipelineCache)
        self.lowpassFilter = LowpassFilter(frequencyCutoff: tapeSpeed.lumaCut, countInSeries: 3, device: device)
        self.lumaLowpassFilter = VHSLumaLowpassFilter(frequencyCutoff: tapeSpeed.lumaCut, device: device, pipelineCache: pipelineCache)
        self.chromaLowpassFilter = VHSChromaLowpassFilter(frequencyCutoff: tapeSpeed.chromaCut, chromaDelay: tapeSpeed.chromaDelay, device: device, pipelineCache: pipelineCache)
        self.sharpenLowpassFilter = VHSSharpenLowpassFilter(frequencyCutoff: tapeSpeed.lumaCut * 4, sharpening: sharpening, device: device, pipelineCache: pipelineCache)
    }
    
    func run(
        input: MTLTexture,
        texA: MTLTexture,
        texB: MTLTexture,
        texC: MTLTexture,
        texD: MTLTexture,
        texE: MTLTexture,
        output: MTLTexture,
        commandBuffer: MTLCommandBuffer
    ) throws {
        do {
            try privateRun(input: input, texA: texA, texB: texB, texC: texC, texD: texD, texE: texE, output: output, commandBuffer: commandBuffer)
        } catch {
            print("Error in private run: \(error)")
            try justBlit(from: input, to: output, commandBuffer: commandBuffer)
        }
    }
    
    private func privateRun(
        input: MTLTexture,
        texA: MTLTexture,
        texB: MTLTexture,
        texC: MTLTexture,
        texD: MTLTexture,
        texE: MTLTexture,
        output: MTLTexture,
        commandBuffer: MTLCommandBuffer
    ) throws {
        let pool = Pool(vals: [texA, texB, texC, texD, texE])
        try writeRandom(to: pool.next(), commandBuffer: commandBuffer)
        try mixRandom(from: pool.last, to: pool.next(), commandBuffer: commandBuffer)
        lowpassFilter.run(input: pool.last, output: pool.next(), commandBuffer: commandBuffer)
        try edgeWave(input: input, random: pool.last, output: pool.next(), commandBuffer: commandBuffer)
        try lumaLowpass(input: pool.last, texA: pool.next(), texB: pool.next(), texC: pool.next(), output: pool.next(), filter: lumaLowpassFilter, commandBuffer: commandBuffer)
        try chromaLowpass(input: pool.last, texA: pool.next(), output: pool.next(), filter: chromaLowpassFilter, commandBuffer: commandBuffer)
        if chromaVertBlend {
            try chromaVertBlend(input: pool.last, output: pool.next(), commandBuffer: commandBuffer)
        }
        try sharpen(input: pool.last, tex: pool.next(), output: pool.next(), commandBuffer: commandBuffer)
        
        if !sVideoOut {
            try chromaIntoLuma(input: pool.last, output: pool.next(), commandBuffer: commandBuffer)
            try accumulateLuma(input: pool.last, output: pool.next(), commandBuffer: commandBuffer)
            try chromaFromLuma(input: pool.last, output: pool.next(), commandBuffer: commandBuffer)
        }
        try justBlit(from: pool.last, to: output, commandBuffer: commandBuffer)
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
        try encodeKernelFunction(.vhsEdgeWave, pipelineCache: pipelineCache, textureWidth: input.width, textureHeight: input.height, commandBuffer: commandBuffer, encode: { encoder in
            encoder.setTexture(input, index: 0)
            encoder.setTexture(random, index: 1)
            encoder.setTexture(output, index: 2)
            var edgeWave = edgeWave
            encoder.setBytes(&edgeWave, length: MemoryLayout<UInt>.size, index: 0)
        })
    }
    
    private func lumaLowpass(input: MTLTexture, texA: MTLTexture, texB: MTLTexture, texC: MTLTexture, output: MTLTexture, filter: VHSLumaLowpassFilter, commandBuffer: MTLCommandBuffer) throws {
        try filter.run(input: input, texA: texA, texB: texB, texC: texC, output: output, commandBuffer: commandBuffer)
    }
    
    func chromaLowpass(input: MTLTexture, texA: MTLTexture, output: MTLTexture, filter: VHSChromaLowpassFilter, commandBuffer: MTLCommandBuffer) throws {
        try filter.run(input: input, texA: texA, output: output, commandBuffer: commandBuffer)
    }
    func chromaVertBlend(input: MTLTexture, output: MTLTexture, commandBuffer: MTLCommandBuffer) throws {
        try encodeKernelFunction(.chromaVertBlend, pipelineCache: pipelineCache, textureWidth: input.width, textureHeight: input.height, commandBuffer: commandBuffer, encode: { encoder in
            encoder.setTexture(input, index: 0)
            encoder.setTexture(output, index: 1)
        })
    }
    func sharpen(input: MTLTexture, tex: MTLTexture, output: MTLTexture, commandBuffer: MTLCommandBuffer) throws {
        try sharpenLowpassFilter.run(input: input, tex: tex, output: output, commandBuffer: commandBuffer)
    }
    
    func chromaIntoLuma(input: MTLTexture, output: MTLTexture, commandBuffer: MTLCommandBuffer) throws {
        try encodeKernelFunction(.chromaIntoLuma, pipelineCache: pipelineCache, textureWidth: input.width, textureHeight: input.height, commandBuffer: commandBuffer, encode: { encoder in
            encoder.setTexture(input, index: 0)
            encoder.setTexture(output, index: 1)
            var phaseShift = phaseShift
            encoder.setBytes(&phaseShift, length: MemoryLayout<Int>.size, index: 0)
            var phaseShiftOffset = phaseShiftOffset
            encoder.setBytes(&phaseShiftOffset, length: MemoryLayout<Int>.size, index: 1)
            var subcarrierAmplitude = subcarrierAmplitude
            encoder.setBytes(&subcarrierAmplitude, length: MemoryLayout<Float16>.size, index: 2)
        })
    }
        
    private func accumulateLuma(input: MTLTexture, output: MTLTexture, commandBuffer: MTLCommandBuffer) throws {
        let pipelineState = try pipelineCache.pipelineState(function: .chromaFromLumaAccumulator)
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw TextureFilterError.cantMakeComputeEncoder
        }
        
        encoder.setComputePipelineState(pipelineState)
        encoder.setTexture(input, index: 0)
        encoder.setTexture(output, index: 1)
        let threadgroups = MTLSize(width: 1, height: 1, depth: 1)
        let threadgroupHeight = input.height <= 1024 ? input.height : 1024
        let threadsPerThreadgroup = MTLSize(width: 1, height: threadgroupHeight, depth: 1)
        encoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadsPerThreadgroup)
        encoder.endEncoding()
    }
    
    func chromaFromLuma(input: MTLTexture, output: MTLTexture, commandBuffer: MTLCommandBuffer) throws {
        try encodeKernelFunction(.chromaFromLuma, pipelineCache: pipelineCache, textureWidth: input.width, textureHeight: input.height, commandBuffer: commandBuffer, encode: { encoder in
            encoder.setTexture(input, index: 0)
            encoder.setTexture(output, index: 1)
            var phaseShift = phaseShift.rawValue
            encoder.setBytes(&phaseShift, length: MemoryLayout<Int>.size, index: 0)
            var phaseShiftOffset = phaseShiftOffset
            encoder.setBytes(&phaseShiftOffset, length: MemoryLayout<Int>.size, index: 1)
            var subcarrierAmplitude = subcarrierAmplitude
            encoder.setBytes(&subcarrierAmplitude, length: MemoryLayout<Float16>.size, index: 2)
        })
    }
}
