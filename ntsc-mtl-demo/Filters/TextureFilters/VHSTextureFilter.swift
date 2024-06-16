//
//  VHSTextureFilter.swift
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-06-04.
//

import Foundation
import Metal
import CoreImage
import CoreImage.CIFilterBuiltins

class VHSTextureFilter {
    typealias Error = TextureFilterError
    
    private let device: MTLDevice
    private let pipelineCache: MetalPipelineCache
    private let ciContext: CIContext
    private let randomGenerator = CIFilter.randomGenerator()
    private var rng = SystemRandomNumberGenerator()
    var bandwidthScale: Float = NTSCEffect.default.bandwidthScale
    var settings: VHSSettings = .default
    
    init(device: MTLDevice, pipelineCache: MetalPipelineCache, ciContext: CIContext) {
        self.device = device
        self.pipelineCache = pipelineCache
        self.ciContext = ciContext
    }
    
    required init?(coder: NSCoder) {
        fatalError("Not implemented")
    }
    
    private var textureA: MTLTexture?
    private var textureB: MTLTexture?
    
    func run(inputTexture: MTLTexture, outputTexture: MTLTexture, commandBuffer: MTLCommandBuffer) throws {
        let needsUpdate: Bool
        if let textureA {
            needsUpdate = !(textureA.width == inputTexture.width && textureA.height == inputTexture.height)
        } else {
            needsUpdate = true
        }
        if needsUpdate {
            let textures = Array(IIRTextureFilter.textures(from: inputTexture, device: device).prefix(2))
            self.textureA = textures[0]
            self.textureB = textures[1]
        }
        guard let textureA, let textureB else {
            throw Error.cantMakeTexture
        }
        let iter = IteratorThing(vals: [textureA, textureB])
        if settings.edgeWaveEnabled {
            try writeRandom(
                to: try iter.next(),
                commandBuffer: commandBuffer
            )
            try edgeWave(
                from: inputTexture,
                randomTexture: try iter.last,
                to: try iter.next(),
                edgeWave: settings.edgeWave,
                commandBuffer: commandBuffer
            )
        }
        try justBlit(from: textureB, to: outputTexture, commandBuffer: commandBuffer)
    }
    
    private func writeRandom(to texture: MTLTexture, commandBuffer: MTLCommandBuffer) throws {
        let randomX: UInt = rng.next(upperBound: 500)
        let randomY: UInt = rng.next(upperBound: 500)
        guard let randomImg = randomGenerator.outputImage?.transformed(by: .init(translationX: CGFloat(randomX), y: CGFloat(randomY))).cropped(to: CGRect(origin: .zero, size: CGSize(width: texture.width, height: texture.height))) else {
            throw Error.cantMakeRandomImage
        }
        
        ciContext.render(randomImg, to: texture, commandBuffer: commandBuffer, bounds: randomImg.extent, colorSpace: ciContext.workingColorSpace ?? CGColorSpaceCreateDeviceRGB())
    }
    
    private func edgeWave(from inputTexture: MTLTexture, randomTexture: MTLTexture, to outputTexture: MTLTexture, edgeWave: VHSEdgeWaveSettings, commandBuffer: MTLCommandBuffer) throws {
        let pipelineState = try pipelineCache.pipelineState(function: .edgeWave)
        guard let commandEncoder = commandBuffer.makeComputeCommandEncoder() else {
            throw Error.cantMakeComputeEncoder
        }
        commandEncoder.setComputePipelineState(pipelineState)
        commandEncoder.setTexture(inputTexture, index: 0)
        commandEncoder.setTexture(randomTexture, index: 1)
        commandEncoder.setTexture(outputTexture, index: 2)
        
        var intensity: Float = edgeWave.intensity
        commandEncoder.setBytes(&intensity, length: MemoryLayout<Float>.size, index: 0)
        var bandwidthScale = bandwidthScale
        commandEncoder.setBytes(&bandwidthScale, length: MemoryLayout<Float>.size, index: 1)
        commandEncoder.dispatchThreads(textureWidth: inputTexture.width, textureHeight: inputTexture.height)
        commandEncoder.endEncoding()
    }
}
