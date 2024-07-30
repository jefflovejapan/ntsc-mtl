//
//  IIRTextureFilter.swift
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-06-03.
//

import Foundation
import CoreImage
import Metal

public class NTSCTextureFilter {
    typealias Error = TextureFilterError

    private let effect: NTSCEffect
    private let device: MTLDevice
    private let context: CIContext
    private let commandQueue: MTLCommandQueue
    private let pipelineCache: MetalPipelineCache
    private var inTextures: [MTLTexture] = []
    private var outTexture1: MTLTexture?
    private var outTexture2: MTLTexture?
    
    private let colorBleedFilter: ColorBleedFilter
    private let compositeLowpassFilter: CompositeLowpassFilter
    private var emulateVHSFilter: EmulateVHSFilter
    private let headSwitchingFilter: HeadSwitchingFilter
    private let noiseFilter: NoiseFilter
    private let compositePreemphasisFilter: CompositePreemphasisFilter
    
    // MARK: -Filters

    
    public var inputImage: CIImage?
    
    public init(effect: NTSCEffect, device: MTLDevice, ciContext: CIContext) throws {
        self.effect = effect
        self.device = device
        self.context = ciContext
        guard let commandQueue = device.makeCommandQueue() else {
            throw Error.cantMakeTexture
        }
        self.commandQueue = commandQueue
        guard let url = Bundle.module.url(forResource: "default", withExtension: "metallib") else {
            throw Error.cantMakeLibrary
        }
        let library = try device.makeLibrary(URL: url)
        self.pipelineCache = try MetalPipelineCache(device: device, library: library)
        self.colorBleedFilter = ColorBleedFilter(pipelineCache: pipelineCache)
        self.compositeLowpassFilter = try CompositeLowpassFilter(device: device, pipelineCache: pipelineCache)
        self.emulateVHSFilter = EmulateVHSFilter(
            tapeSpeed: effect.vhsTapeSpeed,
            sharpening: effect.vhsSharpening,
            phaseShift: effect.scanlinePhaseShift,
            phaseShiftOffset: effect.scanlinePhaseShiftOffset, 
            subcarrierAmplitude: effect.subcarrierAmplitude, 
            chromaVertBlend: effect.vhsChromaVertBlend,
            sVideoOut: effect.vhsSVideoOut, 
            outputNTSC: effect.outputNTSC,
            device: device,
            pipelineCache: pipelineCache,
            ciContext: ciContext
        )
        self.headSwitchingFilter = HeadSwitchingFilter(device: device, pipelineCache: pipelineCache, ciContext: ciContext)
        self.noiseFilter = NoiseFilter(device: device, pipelineCache: pipelineCache, ciContext: ciContext)
        self.compositePreemphasisFilter = CompositePreemphasisFilter(frequencyCutoff: 1_000_000, device: device, pipelineCache: pipelineCache)
    }
    
    static func cutBlackLineBorder(input: MTLTexture, output: MTLTexture, blackLineEnabled: Bool, blackLineBorderPct: Float, commandBuffer: MTLCommandBuffer, device: MTLDevice, pipelineCache: MetalPipelineCache) throws {
        guard blackLineEnabled else {
            try justBlit(from: input, to: output, commandBuffer: commandBuffer)
            return
        }
        
        try encodeKernelFunction(.blackLineBorder, pipelineCache: pipelineCache, textureWidth: input.width, textureHeight: input.height, commandBuffer: commandBuffer, encode: { encoder in
            encoder.setTexture(input, index: 0)
            encoder.setTexture(output, index: 1)
            var blackLineBorderPct = blackLineBorderPct
            encoder.setBytes(&blackLineBorderPct, length: MemoryLayout<Float>.size, index: 0)
        })
    }
        
    static func convertToYIQ(_ texture: (any MTLTexture), output: (any MTLTexture), commandBuffer: MTLCommandBuffer, device: MTLDevice, pipelineCache: MetalPipelineCache) throws {
        // Create a command buffer and encoder
        try encodeKernelFunction(.convertToYIQ, pipelineCache: pipelineCache, textureWidth: texture.width, textureHeight: texture.height, commandBuffer: commandBuffer, encode: { encoder in
            encoder.setTexture(texture, index: 0)
            encoder.setTexture(output, index: 1)
        })
    }
    
    static func colorBleedIn(
        input: MTLTexture,
        output: MTLTexture,
        colorBleedEnabled: Bool,
        colorBleedX: Float,
        colorBleedY: Float,
        filter: ColorBleedFilter,
        commandBuffer: MTLCommandBuffer
    ) throws {
        guard colorBleedEnabled else {
            try justBlit(from: input, to: output, commandBuffer: commandBuffer)
            return
        }
        filter.xOffset = Int(colorBleedX)
        filter.yOffset = Int(colorBleedY)
        try filter.run(input: input, output: output, commandBuffer: commandBuffer)
    }
    
    static func compositeLowpass(input: MTLTexture, texA: MTLTexture, texB: MTLTexture, output: MTLTexture, commandBuffer: MTLCommandBuffer, filter: CompositeLowpassFilter, device: MTLDevice, pipelineCache: MetalPipelineCache) throws {
        try filter.run(input: input, texA: texA, texB: texB, output: output, commandBuffer: commandBuffer)
    }
    
    static func ringing(input: MTLTexture, output: MTLTexture, commandBuffer: MTLCommandBuffer, device: MTLDevice, pipelineCache: MetalPipelineCache) throws {
        try justBlit(from: input, to: output, commandBuffer: commandBuffer)
    }
    
    static func chromaIntoLuma(input: MTLTexture, output: MTLTexture, commandBuffer: MTLCommandBuffer, device: MTLDevice, pipelineCache: MetalPipelineCache) throws {
        try justBlit(from: input, to: output, commandBuffer: commandBuffer)
    }
    
    static func compositePreemphasis(input: MTLTexture, texA: MTLTexture, texB: MTLTexture, output: MTLTexture, filter: CompositePreemphasisFilter, preemphasis: Float16, commandBuffer: MTLCommandBuffer, device: MTLDevice, pipelineCache: MetalPipelineCache) throws {
        filter.preemphasis = preemphasis
        try filter.run(input: input, texA: texA, texB: texB, output: output, commandBuffer: commandBuffer)
    }
    
    static func videoNoise(input: MTLTexture, tex: MTLTexture, output: MTLTexture, filter: NoiseFilter, zoom: Float, contrast: Float, frameNumber: UInt32, commandBuffer: MTLCommandBuffer) throws {
        filter.zoom = zoom
        filter.contrast = contrast
        try filter.run(
            input: input,
            tex: tex,
            output: output,
            commandBuffer: commandBuffer
        )
    }
    
    static func snow(input: MTLTexture, output: MTLTexture, commandBuffer: MTLCommandBuffer, device: MTLDevice, pipelineCache: MetalPipelineCache) throws {
        try justBlit(from: input, to: output, commandBuffer: commandBuffer)
    }
    
    static func vhsHeadSwitching(
        input: MTLTexture,
        tex: MTLTexture,
        output: MTLTexture,
        filter: HeadSwitchingFilter,
        enableHeadSwitching: Bool,
        frameNum: UInt32,
        headSwitchingSpeed: Float16,
        commandBuffer: MTLCommandBuffer,
        device: MTLDevice,
        pipelineCache: MetalPipelineCache
    ) throws {
        guard enableHeadSwitching else {
            try justBlit(from: input, to: output, commandBuffer: commandBuffer)
            return
        }
        filter.headSwitchingSpeed = headSwitchingSpeed
        filter.frameNum = frameNum
        try filter.run(input: input, tex: tex, output: output, commandBuffer: commandBuffer)
    }
    
    static func chromaFromLuma(input: MTLTexture, output: MTLTexture, commandBuffer: MTLCommandBuffer, device: MTLDevice, pipelineCache: MetalPipelineCache) throws {
        try justBlit(from: input, to: output, commandBuffer: commandBuffer)
    }
    
    static func videoChromaNoise(input: MTLTexture, output: MTLTexture, commandBuffer: MTLCommandBuffer, device: MTLDevice, pipelineCache: MetalPipelineCache) throws {
        try justBlit(from: input, to: output, commandBuffer: commandBuffer)
    }
    
    static func videoChromaPhaseNoise(input: MTLTexture, output: MTLTexture, commandBuffer: MTLCommandBuffer, device: MTLDevice, pipelineCache: MetalPipelineCache) throws {
        try justBlit(from: input, to: output, commandBuffer: commandBuffer)
    }
    
    static func emulateVHS(
        input: MTLTexture,
        texA: MTLTexture,
        texB: MTLTexture,
        texC: MTLTexture,
        texD: MTLTexture,
        texE: MTLTexture,
        output: MTLTexture,
        filter: EmulateVHSFilter,
        edgeWave: UInt,
        phaseShift: ScanlinePhaseShift,
        phaseShiftOffset: Int,
        sVideoOut: Bool,
        outputNTSC: Bool,
        commandBuffer: MTLCommandBuffer
    ) throws {
        filter.edgeWave = edgeWave
        filter.phaseShift = phaseShift
        filter.phaseShiftOffset = phaseShiftOffset
        filter.sVideoOut = sVideoOut
        filter.outputNTSC = outputNTSC
        try filter.run(input: input, texA: texA, texB: texB, texC: texC, texD: texD, texE: texE, output: output, commandBuffer: commandBuffer)
    }
    
    static func vhsChromaLoss(input: MTLTexture, output: MTLTexture, commandBuffer: MTLCommandBuffer, device: MTLDevice, pipelineCache: MetalPipelineCache) throws {
        try justBlit(from: input, to: output, commandBuffer: commandBuffer)
    }
    
    static func colorBleedOut(input: MTLTexture, output: MTLTexture, forTV: Bool, commandBuffer: MTLCommandBuffer, device: MTLDevice, pipelineCache: MetalPipelineCache) throws {
        try justBlit(from: input, to: output, commandBuffer: commandBuffer)
    }
    
    static func blurChroma(input: MTLTexture, output: MTLTexture, forTV: Bool, commandBuffer: MTLCommandBuffer, device: MTLDevice, pipelineCache: MetalPipelineCache) throws {
        try justBlit(from: input, to: output, commandBuffer: commandBuffer)
    }
    
    static func convertToRGB(
        _ texture: (any MTLTexture),
        output: (any MTLTexture),
        commandBuffer: MTLCommandBuffer,
        device: MTLDevice, 
        pipelineCache: MetalPipelineCache
    ) throws {
        try encodeKernelFunction(.convertToRGB, pipelineCache: pipelineCache, textureWidth: texture.width, textureHeight: texture.height, commandBuffer: commandBuffer, encode: { encoder in
            encoder.setTexture(texture, index: 0)
            encoder.setTexture(output, index: 1)
        })
    }
    
    static func handle(mostRecentTexture: MTLTexture, previousTexture: MTLTexture, outTexture: MTLTexture, interlaceMode: InterlaceMode, commandBuffer: MTLCommandBuffer, device: MTLDevice, pipelineCache: MetalPipelineCache) throws {
        switch interlaceMode {
        case .full:
            try justBlit(from: mostRecentTexture, to: outTexture, commandBuffer: commandBuffer)
            
        case .interlaced:
            try interleave(mostRecentTexture: mostRecentTexture, previousTexture: previousTexture, outTexture: outTexture, commandBuffer: commandBuffer, device: device, pipelineCache: pipelineCache)
        }
    }
    
    static func interleave(mostRecentTexture: MTLTexture, previousTexture: MTLTexture, outTexture: MTLTexture, commandBuffer: MTLCommandBuffer, device: MTLDevice, pipelineCache: MetalPipelineCache) throws {
        try encodeKernelFunction(.interleave, pipelineCache: pipelineCache, textureWidth: mostRecentTexture.width, textureHeight: mostRecentTexture.height, commandBuffer: commandBuffer, encode: { encoder in
            encoder.setTexture(mostRecentTexture, index: 0)
            encoder.setTexture(previousTexture, index: 1)
            encoder.setTexture(outTexture, index: 2)
        })
    }

    static func writeToFields(
        inputTexture: MTLTexture,
        frameNum: UInt32,
        interlaceMode: InterlaceMode,
        interTexA: MTLTexture,
        interTexB: MTLTexture,
        outTex: MTLTexture,
        commandBuffer: MTLCommandBuffer,
        device: MTLDevice,
        pipelineCache: MetalPipelineCache
    ) throws {
        if frameNum % 2 == 0 {
            try justBlit(from: inputTexture, to: interTexA, commandBuffer: commandBuffer)
            try handle(mostRecentTexture: interTexA, previousTexture: interTexB, outTexture: outTex, interlaceMode: interlaceMode, commandBuffer: commandBuffer, device: device, pipelineCache: pipelineCache)
        } else {
            try justBlit(from: inputTexture, to: interTexB, commandBuffer: commandBuffer)
            try handle(mostRecentTexture: interTexB, previousTexture: interTexA, outTexture: outTex, interlaceMode: interlaceMode, commandBuffer: commandBuffer, device: device, pipelineCache: pipelineCache)
        }
    }
    
    private func setup(with inputImage: CIImage) throws {
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            throw Error.cantMakeCommandBuffer
        }
        defer { commandBuffer.commit() }
        if let textureA = inTextures.first, textureA.width == Int(inputImage.extent.width), textureA.height == Int(inputImage.extent.height) {
            self.context.render(inputImage, to: textureA, commandBuffer: commandBuffer, bounds: inputImage.extent, colorSpace: self.context.workingColorSpace ?? CGColorSpaceCreateDeviceRGB())
            return
        }
        let texCount = 12
        let textures = Array(Texture.textures(width: Int(inputImage.extent.width), height: Int(inputImage.extent.height), pixelFormat: .rgba16Float, device: device).prefix(texCount))
        guard textures.count == texCount else {
            throw Error.cantMakeTexture
        }
        self.inTextures = Array(textures[0 ..< texCount - 2])
        self.outTexture1 = textures[texCount - 2]
        self.outTexture2 = textures[texCount - 1]
        context.render(inputImage, to: inTextures.first!, commandBuffer: commandBuffer, bounds: inputImage.extent, colorSpace: context.workingColorSpace ?? CGColorSpaceCreateDeviceRGB())
    }
    
    private var frameNum: UInt32 = 0
    
    public var outputImage: CIImage? {
        let frameNum = self.frameNum
        defer { self.frameNum += 1 }
        guard let inputImage else { return nil }
        do {
            try setup(with: inputImage)
        } catch {
            print("Error setting up texture with input image: \(error)")
            return nil
        }
        
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            print("Couldn't make command buffer")
            return nil
        }
        let pool = Pool(vals: inTextures)
        
        do {
            try Self.cutBlackLineBorder(
                input: pool.next(),
                output: pool.next(),
                blackLineEnabled: effect.blackLineBorderEnabled,
                blackLineBorderPct: effect.blackLineBorderPct,
                commandBuffer: commandBuffer,
                device: device,
                pipelineCache: pipelineCache
            )
             // Step 0: convert to YIQ
            try Self.convertToYIQ(
                pool.last,
                output: pool.next(),
                commandBuffer: commandBuffer,
                device: device,
                pipelineCache: pipelineCache
            )
            try Self.colorBleedIn(
                input: pool.last,
                output: pool.next(),
                colorBleedEnabled: effect.colorBleedEnabled,
                colorBleedX: effect.colorBleedXOffset,
                colorBleedY: effect.colorBleedYOffset,
                filter: colorBleedFilter,
                commandBuffer: commandBuffer
            )
            
            try Self.compositeLowpass(
                input: pool.last,
                texA: pool.next(),
                texB: pool.next(),
                output: pool.next(),
                commandBuffer: commandBuffer, 
                filter: compositeLowpassFilter,
                device: device,
                pipelineCache: pipelineCache
            )
            
            try Self.ringing(
                input: pool.last,
                output: pool.next(),
                commandBuffer: commandBuffer,
                device: device,
                pipelineCache: pipelineCache
            )
            
            try Self.chromaIntoLuma(
                input: pool.last,
                output: pool.next(),
                commandBuffer: commandBuffer,
                device: device,
                pipelineCache: pipelineCache
            )
            
            try Self.compositePreemphasis(
                input: pool.last,
                texA: pool.next(),
                texB: pool.next(),
                output: pool.next(),
                filter: compositePreemphasisFilter,
                preemphasis: effect.compositePreemphasis,
                commandBuffer: commandBuffer,
                device: device,
                pipelineCache: pipelineCache
            )
            
            try Self.videoNoise(
                input: pool.last,
                tex: pool.next(),
                output: pool.next(),
                filter: noiseFilter,
                zoom: effect.compositeNoiseZoom,
                contrast: effect.compositeNoiseContrast,
                frameNumber: frameNum,
                commandBuffer: commandBuffer
            )
            
            try Self.snow(
                input: pool.last,
                output: pool.next(),
                commandBuffer: commandBuffer,
                device: device,
                pipelineCache: pipelineCache
            )
            
            try Self.vhsHeadSwitching(
                input: pool.last,
                tex: pool.next(),
                output: pool.next(),
                filter: headSwitchingFilter, 
                enableHeadSwitching: effect.enableHeadSwitching, 
                frameNum: frameNum,
                headSwitchingSpeed: effect.headSwitchingSpeed,
                commandBuffer: commandBuffer,
                device: device,
                pipelineCache: pipelineCache
            )
            
            try Self.chromaFromLuma(
                input: pool.last,
                output: pool.next(),
                commandBuffer: commandBuffer,
                device: device,
                pipelineCache: pipelineCache
            )
            
            try Self.videoChromaNoise(
                input: pool.last,
                output: pool.next(),
                commandBuffer: commandBuffer,
                device: device,
                pipelineCache: pipelineCache
            )
            
            try Self.videoChromaPhaseNoise(
                input: pool.last,
                output: pool.next(),
                commandBuffer: commandBuffer,
                device: device,
                pipelineCache: pipelineCache
            )
            
            if !(emulateVHSFilter.tapeSpeed == effect.vhsTapeSpeed && emulateVHSFilter.sharpening == effect.vhsSharpening) {
                emulateVHSFilter = EmulateVHSFilter(
                    tapeSpeed: effect.vhsTapeSpeed,
                    sharpening: effect.vhsSharpening, 
                    phaseShift: effect.scanlinePhaseShift,
                    phaseShiftOffset: effect.scanlinePhaseShiftOffset, subcarrierAmplitude: effect.subcarrierAmplitude, 
                    chromaVertBlend: effect.vhsChromaVertBlend, 
                    sVideoOut: effect.vhsSVideoOut, 
                    outputNTSC: effect.outputNTSC,
                    device: device,
                    pipelineCache: pipelineCache,
                    ciContext: context
                )
            }
            
            if effect.enableVHSEmulation {
                try Self.emulateVHS(
                    input: pool.last,
                    texA: pool.next(),
                    texB: pool.next(),
                    texC: pool.next(),
                    texD: pool.next(),
                    texE: pool.next(),
                    output: pool.next(),
                    filter: emulateVHSFilter,
                    edgeWave: UInt(effect.vhsEdgeWave),
                    phaseShift: effect.scanlinePhaseShift,
                    phaseShiftOffset: effect.scanlinePhaseShiftOffset, 
                    sVideoOut: effect.vhsSVideoOut, 
                    outputNTSC: effect.outputNTSC,
                    commandBuffer: commandBuffer
                )
            }
            
            try Self.vhsChromaLoss(
                input: pool.last,
                output: pool.next(),
                commandBuffer: commandBuffer,
                device: device,
                pipelineCache: pipelineCache
            )

            try Self.compositeLowpass(
                input: pool.last,
                texA: pool.next(),
                texB: pool.next(),
                output: pool.next(),
                commandBuffer: commandBuffer,
                filter: compositeLowpassFilter,
                device: device,
                pipelineCache: pipelineCache
            )
            
            try Self.colorBleedOut(
                input: pool.last,
                output: pool.next(),
                forTV: effect.colorBleedOutForTV,
                commandBuffer: commandBuffer,
                device: device,
                pipelineCache: pipelineCache
            )
            
            try Self.blurChroma(
                input: pool.last,
                output: pool.next(),
                forTV: effect.colorBleedOutForTV,
                commandBuffer: commandBuffer,
                device: device,
                pipelineCache: pipelineCache
            )
            
            try Self.writeToFields(
                inputTexture: pool.last,
                frameNum: frameNum,
                interlaceMode: .interlaced,
                interTexA: outTexture1!,
                interTexB: outTexture2!,
                outTex: pool.next(),
                commandBuffer: commandBuffer,
                device: device,
                pipelineCache: pipelineCache
            )

            try Self.convertToRGB(
                pool.last,
                output: pool.next(),
                commandBuffer: commandBuffer,
                device: device,
                pipelineCache: pipelineCache
            )
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
            return CIImage(mtlTexture: pool.last)
        } catch {
            print("Error generating output image: \(error)")
            return nil
        }
    }
}
