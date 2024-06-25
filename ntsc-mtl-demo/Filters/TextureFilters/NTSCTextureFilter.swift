//
//  IIRTextureFilter.swift
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-06-03.
//

import Foundation
import CoreImage
import Metal

class NTSCTextureFilter {
    typealias Error = TextureFilterError

    private let effect: NTSCEffect
    private let device: MTLDevice
    private let context: CIContext
    private let commandQueue: MTLCommandQueue
    private let pipelineCache: MetalPipelineCache
    private var textureA: MTLTexture?
    private var textureB: MTLTexture?
    private var textureC: MTLTexture?
    private var outTexture1: MTLTexture?
    private var outTexture2: MTLTexture?
    private var outTexture3: MTLTexture?
    
    private let colorBleedFilter: ColorBleedFilter
    private let compositeLowpassFilter: CompositeLowpassFilter
    private var emulateVHSFilter: EmulateVHSFilter
    private let headSwitchingFilter: HeadSwitchingFilter
    
    // MARK: -Filters

    
    var inputImage: CIImage?
    
    init(effect: NTSCEffect, device: MTLDevice, ciContext: CIContext) throws {
        self.effect = effect
        self.device = device
        self.context = ciContext
        guard let commandQueue = device.makeCommandQueue() else {
            throw Error.cantMakeTexture
        }
        self.commandQueue = commandQueue
        guard let library = device.makeDefaultLibrary() else {
            throw Error.cantMakeLibrary
        }
        self.pipelineCache = try MetalPipelineCache(device: device, library: library)
        self.colorBleedFilter = ColorBleedFilter(device: device, pipelineCache: pipelineCache)
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
        self.headSwitchingFilter = HeadSwitchingFilter(device: device, pipelineCache: pipelineCache)
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
    
    static func compositeLowpass(input: MTLTexture, output: MTLTexture, commandBuffer: MTLCommandBuffer, filter: CompositeLowpassFilter, device: MTLDevice, pipelineCache: MetalPipelineCache) throws {
        try filter.run(input: input, output: output, commandBuffer: commandBuffer)
    }
    
    static func ringing(input: MTLTexture, output: MTLTexture, commandBuffer: MTLCommandBuffer, device: MTLDevice, pipelineCache: MetalPipelineCache) throws {
        try justBlit(from: input, to: output, commandBuffer: commandBuffer)
    }
    
    static func chromaIntoLuma(input: MTLTexture, output: MTLTexture, commandBuffer: MTLCommandBuffer, device: MTLDevice, pipelineCache: MetalPipelineCache) throws {
        try justBlit(from: input, to: output, commandBuffer: commandBuffer)
    }
    
    static func compositePreemphasis(input: MTLTexture, output: MTLTexture, commandBuffer: MTLCommandBuffer, device: MTLDevice, pipelineCache: MetalPipelineCache) throws {
        try justBlit(from: input, to: output, commandBuffer: commandBuffer)
    }
    
    static func videoNoise(input: MTLTexture, output: MTLTexture, commandBuffer: MTLCommandBuffer, device: MTLDevice, pipelineCache: MetalPipelineCache) throws {
        try justBlit(from: input, to: output, commandBuffer: commandBuffer)
    }
    
    static func vhsHeadSwitching(input: MTLTexture, output: MTLTexture, filter: HeadSwitchingFilter, commandBuffer: MTLCommandBuffer, device: MTLDevice, pipelineCache: MetalPipelineCache) throws {
        try filter.run(input: input, output: output, commandBuffer: commandBuffer)
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
    
    static func emulateVHS(input: MTLTexture, output: MTLTexture, filter: EmulateVHSFilter, edgeWave: UInt, phaseShift: ScanlinePhaseShift, phaseShiftOffset: Int, sVideoOut: Bool, outputNTSC: Bool, commandBuffer: MTLCommandBuffer) throws {
        filter.edgeWave = edgeWave
        filter.phaseShift = phaseShift
        filter.phaseShiftOffset = phaseShiftOffset
        filter.sVideoOut = sVideoOut
        filter.outputNTSC = outputNTSC
        try filter.run(input: input, output: output, commandBuffer: commandBuffer)
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
        if let textureA, textureA.width == Int(inputImage.extent.width), textureA.height == Int(inputImage.extent.height) {
            self.context.render(inputImage, to: textureA, commandBuffer: commandBuffer, bounds: inputImage.extent, colorSpace: self.context.workingColorSpace ?? CGColorSpaceCreateDeviceRGB())
            return
        }
        let textures = Array(Texture.textures(width: Int(inputImage.extent.width), height: Int(inputImage.extent.height), pixelFormat: .rgba16Float, device: device).prefix(6))
        guard textures.count == 6 else {
            throw Error.cantMakeTexture
        }
        self.textureA = textures[0]
        self.textureB = textures[1]
        self.textureC = textures[2]
        self.outTexture1 = textures[3]
        self.outTexture2 = textures[4]
        self.outTexture3 = textures[5]
        context.render(inputImage, to: textureA!, commandBuffer: commandBuffer, bounds: inputImage.extent, colorSpace: context.workingColorSpace ?? CGColorSpaceCreateDeviceRGB())
    }
    
    private var frameNum: UInt32 = 0
    
    var outputImage: CIImage? {
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
        let textures: [MTLTexture] = [textureA!, textureB!, textureC!]
        let iter = IteratorThing(vals: textures)
        
        do {
            try Self.cutBlackLineBorder(
                input: try iter.next(),
                output: try iter.next(),
                blackLineEnabled: effect.blackLineBorderEnabled,
                blackLineBorderPct: effect.blackLineBorderPct,
                commandBuffer: commandBuffer,
                device: device,
                pipelineCache: pipelineCache
            )
             // Step 0: convert to YIQ
            try Self.convertToYIQ(
                try iter.last,
                output: try iter.next(),
                commandBuffer: commandBuffer,
                device: device,
                pipelineCache: pipelineCache
            )
            try Self.colorBleedIn(
                input: try iter.last,
                output: try iter.next(),
                colorBleedEnabled: effect.colorBleedEnabled,
                colorBleedX: effect.colorBleedXOffset,
                colorBleedY: effect.colorBleedYOffset,
                filter: colorBleedFilter,
                commandBuffer: commandBuffer
            )
            
            try Self.compositeLowpass(
                input: try iter.last,
                output: try iter.next(),
                commandBuffer: commandBuffer, 
                filter: compositeLowpassFilter,
                device: device,
                pipelineCache: pipelineCache
            )
            
            try Self.ringing(
                input: try iter.last,
                output: try iter.next(),
                commandBuffer: commandBuffer,
                device: device,
                pipelineCache: pipelineCache
            )
            
            try Self.chromaIntoLuma(
                input: try iter.last,
                output: try iter.next(),
                commandBuffer: commandBuffer,
                device: device,
                pipelineCache: pipelineCache
            )
            
            try Self.compositePreemphasis(
                input: try iter.last,
                output: try iter.next(),
                commandBuffer: commandBuffer,
                device: device,
                pipelineCache: pipelineCache
            )
            
            try Self.videoNoise(
                input: try iter.last,
                output: try iter.next(),
                commandBuffer: commandBuffer,
                device: device,
                pipelineCache: pipelineCache
            )
            
            try Self.vhsHeadSwitching(
                input: try iter.last,
                output: try iter.next(),
                filter: headSwitchingFilter,
                commandBuffer: commandBuffer,
                device: device,
                pipelineCache: pipelineCache
            )
            
            try Self.chromaFromLuma(
                input: try iter.last,
                output: try iter.next(),
                commandBuffer: commandBuffer,
                device: device,
                pipelineCache: pipelineCache
            )
            
            try Self.videoChromaNoise(
                input: try iter.last,
                output: try iter.next(),
                commandBuffer: commandBuffer,
                device: device,
                pipelineCache: pipelineCache
            )
            
            try Self.videoChromaPhaseNoise(
                input: try iter.last,
                output: try iter.next(),
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
                    input: try iter.last,
                    output: try iter.next(),
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
                input: try iter.last,
                output: try iter.next(),
                commandBuffer: commandBuffer,
                device: device,
                pipelineCache: pipelineCache
            )

            try Self.compositeLowpass(
                input: try iter.last,
                output: try iter.next(),
                commandBuffer: commandBuffer,
                filter: compositeLowpassFilter,
                device: device,
                pipelineCache: pipelineCache
            )
            
            try Self.colorBleedOut(
                input: try iter.last,
                output: try iter.next(),
                forTV: effect.colorBleedOutForTV,
                commandBuffer: commandBuffer,
                device: device,
                pipelineCache: pipelineCache
            )
            
            try Self.blurChroma(
                input: try iter.last,
                output: try iter.next(),
                forTV: effect.colorBleedOutForTV,
                commandBuffer: commandBuffer,
                device: device,
                pipelineCache: pipelineCache
            )
            
            try Self.writeToFields(
                inputTexture: try iter.last,
                frameNum: frameNum,
                interlaceMode: .interlaced,
                interTexA: outTexture1!,
                interTexB: outTexture2!,
                outTex: try iter.next(),
                commandBuffer: commandBuffer,
                device: device,
                pipelineCache: pipelineCache
            )

            try Self.convertToRGB(
                try iter.last,
                output: try iter.next(),
                commandBuffer: commandBuffer,
                device: device,
                pipelineCache: pipelineCache
            )
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
            return CIImage(mtlTexture: try iter.last)
        } catch {
            print("Error generating output image: \(error)")
            return nil
        }
    }
}
