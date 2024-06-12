//
//  CompositeNoiseTextureFilter.swift
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-06-05.
//

import CoreImage
import Foundation
import SimplexNoiseFilter
import Metal

class CompositeNoiseTextureFilter {
    typealias Error = TextureFilterError
    private let simplexNoise = SimplexNoiseGenerator()
    private var simplexNoiseTexture: MTLTexture?
    var noise: FBMNoiseSettings?
    private var rng = SystemRandomNumberGenerator()
    private let device: MTLDevice
    private let library: MTLLibrary
    private let ciContext: CIContext
    private let pipelineCache: MetalPipelineCache
    private static let defaultIntensity: Float16 = 0.05
    
    init(device: MTLDevice, library: MTLLibrary, ciContext: CIContext, pipelineCache: MetalPipelineCache) {
        self.device = device
        self.library = library
        self.ciContext = ciContext
        self.pipelineCache = pipelineCache
    }
    
    func run(inputTexture: MTLTexture, outputTexture: MTLTexture, commandBuffer: MTLCommandBuffer) throws {
        guard var noise else {
            try justBlit(from: inputTexture, to: outputTexture, commandBuffer: commandBuffer)
            return
        }
        let nextX: UInt8 = rng.next(upperBound: 100)
        let nextY: UInt8 = rng.next(upperBound: 100)
        simplexNoise.offsetX = Float(nextX)
        simplexNoise.offsetY = Float(nextY)
        guard let noiseImage = simplexNoise.outputImage?.cropped(to: CGRect(origin: .zero, size: CGSize(width: inputTexture.width, height: inputTexture.height))) else {
            return
        }
        let needsUpdate: Bool
        if let simplexNoiseTexture {
            needsUpdate = !(simplexNoiseTexture.width == inputTexture.width || simplexNoiseTexture.height == inputTexture.height)
        } else {
            needsUpdate = true
        }
        
        if needsUpdate {
            self.simplexNoiseTexture = IIRTextureFilter.texture(from: inputTexture, device: device)
        }
        guard let simplexNoiseTexture else {
            throw Error.cantMakeTexture
        }
        
        ciContext.render(noiseImage, to: simplexNoiseTexture, commandBuffer: commandBuffer, bounds: noiseImage.extent, colorSpace: ciContext.workingColorSpace ?? CGColorSpaceCreateDeviceRGB())
        guard let commandEncoder = commandBuffer.makeComputeCommandEncoder() else {
            throw Error.cantMakeComputeEncoder
        }
        let pipelineState: MTLComputePipelineState = try pipelineCache.pipelineState(function: .multiplyLuma)
        commandEncoder.setComputePipelineState(pipelineState)
        commandEncoder.setTexture(inputTexture, index: 0)
        commandEncoder.setTexture(simplexNoiseTexture, index: 1)
        commandEncoder.setTexture(outputTexture, index: 2)
        var intensity = noise.intensity
        commandEncoder.setBytes(&intensity, length: MemoryLayout<Float16>.size, index: 0)
        commandEncoder.dispatchThreads(textureWidth: inputTexture.width, textureHeight: inputTexture.height)
        commandEncoder.endEncoding()
    }
    
}
