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
    private let context: CIContext
    private let pipelineCache: MetalPipelineCache
    var settings: HeadSwitchingSettings = HeadSwitchingSettings.default
    var bandwidthScale: Float = NTSCEffect.default.bandwidthScale
    private var randomImageTexture: MTLTexture?
    init(device: MTLDevice, ciContext: CIContext, pipelineCache: MetalPipelineCache) {
        self.device = device
        self.context = ciContext
        self.pipelineCache = pipelineCache
    }
    
    func run(inputTexture: MTLTexture, outputTexture: MTLTexture, commandBuffer: MTLCommandBuffer) throws {
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
            throw Error.cantMakeTexture
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
        if let midLine = settings.midLine {
            try shiftRowMidline(
                inputTexture: inputTexture,
                randomTexture: randomImageTexture,
                outputTexture: outputTexture,
                commandBuffer: commandBuffer
            )
        } else {
            try shiftRow(
                inputTexture: inputTexture,
                randomTexture: randomImageTexture,
                outputTexture: outputTexture,
                height: settings.height,
                offset: settings.offset,
                horizShift: settings.horizShift,
                boundaryHandling: .constant(0),
                bandwidthScale: bandwidthScale,
                commandBuffer: commandBuffer
            )
        }
    }

    private let randomImageGenerator = CIFilter.randomGenerator()
    private var randomNumberGenerator = SystemRandomNumberGenerator()
    
    private func shiftRow(
        inputTexture: MTLTexture,
        randomTexture: MTLTexture,
        outputTexture: MTLTexture,
        height: UInt,
        offset: UInt,
        horizShift: Float,
        boundaryHandling: BoundaryHandling,
        bandwidthScale: Float,
        commandBuffer: MTLCommandBuffer
    ) throws {
        let pipelineState: MTLComputePipelineState = try pipelineCache.pipelineState(function: .shiftRow)
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
        
        var effectHeight: UInt = height
        commandEncoder.setBytes(&effectHeight, length: MemoryLayout<UInt>.size, index: 0)
        
        var offsetRows: UInt = offset;
        commandEncoder.setBytes(&offsetRows, length: MemoryLayout<UInt>.size, index: 1)
        
        var shift = horizShift
        commandEncoder.setBytes(&shift, length: MemoryLayout<Float>.size, index: 2)
        
        var bandwidthScale = bandwidthScale
        commandEncoder.setBytes(&bandwidthScale, length: MemoryLayout<Float>.size, index: 3)
        
        commandEncoder.dispatchThreads(textureWidth: inputTexture.width, textureHeight: inputTexture.height)
        commandEncoder.endEncoding()
    }
    
    private func shiftRowMidline(inputTexture: MTLTexture, randomTexture: MTLTexture, outputTexture: MTLTexture, commandBuffer: MTLCommandBuffer) throws {
        let pipelineState: MTLComputePipelineState = try pipelineCache.pipelineState(function: .shiftRowMidline)
        
        guard let randomImage = randomImageGenerator.outputImage else {
            throw Error.cantMakeRandomImage
        }
        
        let randomXTranslation = CGFloat.random(in: -100..<100, using: &randomNumberGenerator)
        let randomYTranslation = CGFloat.random(in: -100..<100, using: &randomNumberGenerator)
        let translatedImage = randomImage.transformed(by: CGAffineTransform(translationX: randomXTranslation, y: randomYTranslation))
        context.render(translatedImage, to: randomTexture, commandBuffer: commandBuffer, bounds: CGRect(origin: .zero, size: CGSize(width: inputTexture.width, height: outputTexture.height)), colorSpace: context.workingColorSpace ?? CGColorSpaceCreateDeviceRGB())
        
        guard let commandEncoder = commandBuffer.makeComputeCommandEncoder() else {
            throw Error.cantMakeComputeEncoder
        }
        
        commandEncoder.setComputePipelineState(pipelineState)
        commandEncoder.setTexture(inputTexture, index: 0)
        commandEncoder.setTexture(randomTexture, index: 1)
        commandEncoder.setTexture(outputTexture, index: 2)
        commandEncoder.dispatchThreads(textureWidth: inputTexture.width, textureHeight: inputTexture.height)
        commandEncoder.endEncoding()
    }
}
