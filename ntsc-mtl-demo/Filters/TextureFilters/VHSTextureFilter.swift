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
////        try writeRandom(to: textureA, commandBuffer: commandBuffer)
//        try edgeWave(from: inputTexture, randomTexture: textureA, to: textureB, commandBuffer: commandBuffer)
        try justBlit(from: inputTexture, to: textureB, commandBuffer: commandBuffer)
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
    
    private func edgeWave(from inputTexture: MTLTexture, randomTexture: MTLTexture, to outputTexture: MTLTexture, commandBuffer: MTLCommandBuffer) throws {
        let pipelineState = try pipelineCache.pipelineState(function: .shiftRow)
        guard let commandEncoder = commandBuffer.makeComputeCommandEncoder() else {
            throw Error.cantMakeComputeEncoder
        }
        commandEncoder.setComputePipelineState(pipelineState)
        commandEncoder.setTexture(inputTexture, index: 0)
        commandEncoder.setTexture(randomTexture, index: 1)
        commandEncoder.setTexture(outputTexture, index: 2)
        
        var effectHeight: UInt = 200
        commandEncoder.setBytes(&effectHeight, length: MemoryLayout<UInt>.size, index: 0)
        var offsetRows: UInt = 100
        commandEncoder.setBytes(&offsetRows, length: MemoryLayout<UInt>.size, index: 1)
        var shift: Float = 17
        commandEncoder.setBytes(&shift, length: MemoryLayout<Float>.size, index: 2)
        var boundaryColumnIndex: UInt = 0
        commandEncoder.setBytes(&boundaryColumnIndex, length: MemoryLayout<UInt>.size, index: 3)
        var bandwidthScale = bandwidthScale
        commandEncoder.setBytes(&bandwidthScale, length: MemoryLayout<Float>.size, index: 4)
        commandEncoder.endEncoding()
    }
}
