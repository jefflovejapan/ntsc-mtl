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
    var bandwidthScale: Float = NTSCEffect.default.bandwidthScale
    private var randomImageTexture: MTLTexture?
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
        
        let needsUpdate: Bool
        if let randomImageTexture {
            needsUpdate = !(randomImageTexture.width == inputTexture.width && randomImageTexture.height == inputTexture.height)
        } else {
            needsUpdate = true
        }
        if needsUpdate {
            randomImageTexture = IIRTextureFilter.texture(from: inputTexture, device: device)
        }
        
        guard let randomImageTexture else {
            throw Error.cantInstantiateTexture
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
            try shiftRowMidline(
                inputTexture: inputTexture,
                outputTexture: outputTexture,
                commandBuffer: commandBuffer
            )
        } else {
            try shiftRow(
                inputTexture: inputTexture,
                randomTexture: randomImageTexture,
                outputTexture: outputTexture,
                shift: hs.horizShift,
                offset: hs.offset,
                boundaryHandling: .constant(0),
                bandwidthScale: bandwidthScale,
                commandBuffer: commandBuffer
            )
        }
    }
    
    private var shiftRowPipelineState: MTLComputePipelineState?
    private var shiftRowMidlinePipelineState: MTLComputePipelineState?
    private let randomImageGenerator = CIFilter.randomGenerator()
    private var randomNumberGenerator = SystemRandomNumberGenerator()
    
    private func shiftRow(inputTexture: MTLTexture, randomTexture: MTLTexture, outputTexture: MTLTexture, shift: Float, offset: UInt, boundaryHandling: BoundaryHandling, bandwidthScale: Float, commandBuffer: MTLCommandBuffer) throws {
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
        guard let randomImage: CIImage = randomImageGenerator.outputImage else {
            throw Error.cantMakeRandomImage
        }
        let randomXTranslation = CGFloat.random(in: -100..<100, using: &randomNumberGenerator)
        let randomYTranslation = CGFloat.random(in: -100..<100, using: &randomNumberGenerator)
        let translatedImage = randomImage.transformed(by: CGAffineTransform(translationX: randomXTranslation, y: randomYTranslation)).cropped(
            to: CGRect(
                origin: .zero,
                size: CGSize(
                    width: inputTexture.width,
                    height: inputTexture.height
                )
            )
        )
        context.render(
            translatedImage,
            to: randomTexture,
            commandBuffer: commandBuffer,
            bounds: CGRect(
                origin: .zero,
                size: CGSize(
                    width: CGFloat(inputTexture.width),
                    height: CGFloat(inputTexture.height)
                )
            ),
            colorSpace: context.workingColorSpace ?? CGColorSpaceCreateDeviceRGB()
        )
        guard let commandEncoder = commandBuffer.makeComputeCommandEncoder() else {
            throw Error.cantMakeComputeEncoder
        }
        commandEncoder.setComputePipelineState(pipelineState)
        commandEncoder.setTexture(inputTexture, index: 0)
        commandEncoder.setTexture(randomTexture, index: 1)
        commandEncoder.setTexture(outputTexture, index: 2)
        var offsetRows: UInt = offset;
        commandEncoder.setBytes(&offsetRows, length: MemoryLayout<UInt>.size, index: 0)
        var boundaryColumnIndex: UInt = UInt(inputTexture.width - 1)
        commandEncoder.setBytes(&boundaryColumnIndex, length: MemoryLayout<UInt>.size, index: 1)
        var shift = shift
        commandEncoder.setBytes(&shift, length: MemoryLayout<Float>.size, index: 2)
        var bandwidthScale = bandwidthScale
        commandEncoder.setBytes(&bandwidthScale, length: MemoryLayout<Float>.size, index: 3)
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
