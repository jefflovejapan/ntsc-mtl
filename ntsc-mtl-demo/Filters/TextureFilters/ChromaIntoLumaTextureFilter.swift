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
    var chromaIntoLumaPipelineState: MTLComputePipelineState?
    func run(
        inputTexture: MTLTexture,
        outputTexture: MTLTexture,
        timestamp: UInt32,
        phaseShift: PhaseShift,
        phaseShiftOffset: Int,
        library: MTLLibrary,
        device: MTLDevice,
        commandBuffer: MTLCommandBuffer
    ) throws {
        let pipelineState: MTLComputePipelineState
        if let chromaIntoLumaPipelineState {
            pipelineState = chromaIntoLumaPipelineState
        } else {
            let functionName = "chromaIntoLuma"
            guard let function = library.makeFunction(name: functionName) else {
                throw Error.cantMakeFunction(functionName)
            }
            pipelineState = try device.makeComputePipelineState(function: function)
            self.chromaIntoLumaPipelineState = pipelineState
        }
        
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
        commandEncoder.dispatchThreads(
            MTLSize(width: inputTexture.width, height: inputTexture.height, depth: 1),
            threadsPerThreadgroup: MTLSize(width: 8, height: 8, depth: 1))
        commandEncoder.endEncoding()
    }
}
