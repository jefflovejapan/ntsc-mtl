//
//  TrackingNoiseTextureFilter.swift
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-06-15.
//

import Foundation
import Metal
import CoreImage

class TrackingNoiseTextureFilter {
    typealias Error = TextureFilterError
    private let device: MTLDevice
    private let ciContext: CIContext
    private let pipelineCache: MetalPipelineCache
    private var wipTextureA: MTLTexture?
    private var wipTextureB: MTLTexture?
        
    var trackingNoiseSettings: TrackingNoiseSettings = .default
    init(device: MTLDevice, ciContext: CIContext, pipelineCache: MetalPipelineCache) {
        self.device = device
        self.ciContext = ciContext
        self.pipelineCache = pipelineCache
    }
    
    func run(inputTexture: MTLTexture, outputTexture: MTLTexture, commandBuffer: MTLCommandBuffer) throws {
        let needsUpdate: Bool
        if let wipTextureA {
            needsUpdate = !(wipTextureA.width == inputTexture.width && wipTextureA.height == inputTexture.height)
        } else {
            needsUpdate = true
        }
        if needsUpdate {
            let texs = Array(IIRTextureFilter.textures(from: inputTexture, device: device).prefix(2))
            self.wipTextureA = texs[0]
            self.wipTextureB = texs[1]
        }

        guard let wipTextureA, let wipTextureB else {
            throw Error.cantMakeTexture
        }
        let iter = IteratorThing(vals: [wipTextureA, wipTextureB])
        
        /*
         - Blit inputTexture to another tex
         - run shiftRow on it
         - run videoNoiseLine on it
         - run snow on it
         */
        try justBlit(from: inputTexture, to: iter.next(), commandBuffer: commandBuffer)
        try shiftRow(input: try iter.last, textureA: try iter.next(), output: try iter.next(), commandBuffer: commandBuffer)
//        try addNoise(input: try iter.last, output: try iter.next(), commandBuffer: commandBuffer)
//        try addSnow(input: try iter.last, output: try iter.next(), commandBuffer: commandBuffer)
//        try blend(input: inputTexture, altered: try iter.last, output: outputTexture, commandBuffer: commandBuffer)
    }
    
    private func shiftRow(input: MTLTexture, textureA: MTLTexture, output: MTLTexture, commandBuffer: MTLCommandBuffer) throws {
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw Error.cantMakeComputeEncoder
        }
        let pipelineState = try pipelineCache.pipelineState(function: .shiftRow)
        encoder.setComputePipelineState(pipelineState)
        encoder.setTexture(input, index: 0)
        encoder.setTexture(textureA, index: 1)
        encoder.setTexture(output, index: 2)
        var effectHeight = trackingNoiseSettings.height
        encoder.setBytes(&effectHeight, length: MemoryLayout<UInt>.size, index: 0)
        var offsetRows: UInt = 0
        encoder.setBytes(&offsetRows, length: MemoryLayout<UInt>.size, index: 1)
        
        encoder.dispatchThreads(textureWidth: input.width, textureHeight: input.height)
        encoder.endEncoding()
    }
    private func addNoise(input: MTLTexture, output: MTLTexture, commandBuffer: MTLCommandBuffer) throws {
        try justBlit(from: input, to: output, commandBuffer: commandBuffer)
//        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
//            throw Error.cantMakeComputeEncoder
//        }
//        let pipelineState = try pipelineCache.pipelineState(function: .noise)
//        encoder.setComputePipelineState(pipelineState)
//        encoder.dispatchThreads(textureWidth: input.width, textureHeight: input.height)
//        encoder.endEncoding()
    }
    private func addSnow(input: MTLTexture, output: MTLTexture, commandBuffer: MTLCommandBuffer) throws {
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw Error.cantMakeComputeEncoder
        }
        let pipelineState = try pipelineCache.pipelineState(function: .snow)
        encoder.setComputePipelineState(pipelineState)
        encoder.dispatchThreads(textureWidth: input.width, textureHeight: input.height)
        encoder.endEncoding()
    }
    private func blend(input: MTLTexture, altered: MTLTexture, output: MTLTexture, commandBuffer: MTLCommandBuffer) throws {
        try justBlit(from: input, to: output, commandBuffer: commandBuffer)
//        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
//            throw Error.cantMakeComputeEncoder
//        }
//        let pipelineState = try pipelineCache.pipelineState(function: .blend)
//        encoder.setComputePipelineState(pipelineState)
//        encoder.dispatchThreads(textureWidth: input.width, textureHeight: input.height)
//        encoder.endEncoding()
    }
}
