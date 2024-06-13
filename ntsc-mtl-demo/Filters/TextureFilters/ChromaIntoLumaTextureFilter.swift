//
//  ChromaIntoLumaTextureFilter.swift
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-06-05.
//

import Foundation
import Metal

class ChromaIntoLumaTextureFilter {
    typealias Error = TextureFilterError
    private let device: MTLDevice
    private let pipelineCache: MetalPipelineCache
    
    init(device: MTLDevice, pipelineCache: MetalPipelineCache) {
        self.device = device
        self.pipelineCache = pipelineCache
    }
    
    func run(
        inputTexture: MTLTexture,
        outputTexture: MTLTexture,
        timestamp: UInt32,
        phaseShift: PhaseShift,
        phaseShiftOffset: Int,
        commandBuffer: MTLCommandBuffer
    ) throws {
        let pipelineState: MTLComputePipelineState = try pipelineCache.pipelineState(function: .chromaIntoLuma)
        
        guard let commandEncoder = commandBuffer.makeComputeCommandEncoder() else {
            throw Error.cantMakeComputeEncoder
        }
        commandEncoder.setComputePipelineState(pipelineState)
        commandEncoder.setTexture(inputTexture, index: 0)
        commandEncoder.setTexture(outputTexture, index: 1)
        var timestamp = timestamp
        commandEncoder.setBytes(&timestamp, length: MemoryLayout<UInt64>.size, index: 0)
        var phaseShiftRaw = phaseShift.rawValue
        commandEncoder.setBytes(&phaseShiftRaw, length: MemoryLayout<UInt>.size, index: 1)
        var phaseShiftOffset = phaseShiftOffset
        commandEncoder.setBytes(&phaseShiftOffset, length: MemoryLayout<Int>.size, index: 2)
        commandEncoder.dispatchThreads(textureWidth: inputTexture.width, textureHeight: inputTexture.height)
        commandEncoder.endEncoding()
    }
}
