//
//  HeadSwitchingTextureFilter.swift
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-06-07.
//

import Foundation
import Metal
import CoreImage

class HeadSwitchingTextureFilter {
    typealias Error = TextureFilterError
    private let device: MTLDevice
    private let library: MTLLibrary
    private let context: CIContext
    var headSwitchingSettings: HeadSwitchingSettings?
    init(device: MTLDevice, library: MTLLibrary, ciContext: CIContext) {
        self.device = device
        self.library = library
        self.context = ciContext
    }
    
    func run(inputTexture: MTLTexture, outputTexture: MTLTexture, commandBuffer: MTLCommandBuffer) throws {
        guard let hs = headSwitchingSettings else {
            try justBlit(inputTexture: inputTexture, outputTexture: outputTexture, commandBuffer: commandBuffer)
            return
        }
//        /*
//         We're getting called with num_rows, offset, shift, and mid_line -- what are these?
//            - they all come directly from headSwitchingSettings
//         */
//        
//        // offset is part of effect, so numAffected is f(effect)
//        let numAffectedRows = inputTexture.height - Int(hs.offset)
//        
//        // width and height from tex
//        let width = inputTexture.width
//        let height = inputTexture.height
//        
//        // which row does the effect start at?
//        let startRow = max(height, numAffectedRows) - numAffectedRows
//        
//        // not sure why we're multiplying by width here...
////         let affected_rows = &mut yiq.y[start_row * width..];
//        // I think it might be because yiq stores all values in a flat array -- this is giving us the slice of pixels that we care about for the effect. Don't think we care about it in shadertown
//        
//        // Can numAffectedRows > height? Looks like numAffectedRows is height - offset so maybe if there's a negative offset?
//
//        let cutOffRows: Int
//        if numAffectedRows > height {
//            cutOffRows = numAffectedRows - height
//        } else {
//            cutOffRows = 0
//        }
//        
//        let shift = hs.horizShift
        if let midLine = hs.midLine {
            try shiftRowMidline(inputTexture: inputTexture, outputTexture: outputTexture, commandBuffer: commandBuffer)
        } else {
            try shiftRow(inputTexture: inputTexture, outputTexture: outputTexture, boundaryHandling: .constant(0), commandBuffer: commandBuffer)
        }
    }
    
    private var shiftRowPipelineState: MTLComputePipelineState?
    private var shiftRowMidlinePipelineState: MTLComputePipelineState?
    
    private func shiftRow(inputTexture: MTLTexture, outputTexture: MTLTexture, boundaryHandling: BoundaryHandling, commandBuffer: MTLCommandBuffer) throws {
        let pipelineState: MTLComputePipelineState
        if let shiftRowPipelineState {
            pipelineState = shiftRowPipelineState
        } else {
            let functionName = "shiftRow"
            guard let function = library.makeFunction(name: functionName) else {
                throw Error.cantMakeFunction(functionName)
            }
            pipelineState = try device.makeComputePipelineState(function: function)
            self.shiftRowPipelineState = pipelineState
        }
        guard let commandEncoder = commandBuffer.makeComputeCommandEncoder() else {
            throw Error.cantMakeComputeEncoder
        }
        commandEncoder.setComputePipelineState(pipelineState)
        commandEncoder.setTexture(inputTexture, index: 0)
        commandEncoder.setTexture(outputTexture, index: 1)
        commandEncoder.dispatchThreads(
            MTLSize(width: inputTexture.width, height: inputTexture.height, depth: 1),
            threadsPerThreadgroup: MTLSize(width: 8, height: 8, depth: 1)
        )
        commandEncoder.endEncoding()
    }
    
    private func shiftRowMidline(inputTexture: MTLTexture, outputTexture: MTLTexture, commandBuffer: MTLCommandBuffer) throws {
        let pipelineState: MTLComputePipelineState
        if let shiftRowMidlinePipelineState {
            pipelineState = shiftRowMidlinePipelineState
        } else {
            let functionName = "shiftRowMidline"
            guard let function = library.makeFunction(name: functionName) else {
                throw Error.cantMakeFunction(functionName)
            }
            pipelineState = try device.makeComputePipelineState(function: function)
            self.shiftRowPipelineState = pipelineState
        }
        guard let commandEncoder = commandBuffer.makeComputeCommandEncoder() else {
            throw Error.cantMakeComputeEncoder
        }
        commandEncoder.setComputePipelineState(pipelineState)
        commandEncoder.setTexture(inputTexture, index: 0)
        commandEncoder.setTexture(outputTexture, index: 1)
        commandEncoder.dispatchThreads(
            MTLSize(width: inputTexture.width, height: inputTexture.height, depth: 1),
            threadsPerThreadgroup: MTLSize(width: 8, height: 8, depth: 1)
        )
        commandEncoder.endEncoding()
    }
    
    private func justBlit(inputTexture: MTLTexture, outputTexture: MTLTexture, commandBuffer: MTLCommandBuffer) throws {
        guard let blitEncoder = commandBuffer.makeBlitCommandEncoder() else {
            throw Error.cantMakeBlitEncoder
        }
        blitEncoder.copy(from: inputTexture, to: outputTexture)
        blitEncoder.endEncoding()
    }
}
