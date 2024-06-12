//
//  SnowTextureFilter.swift
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-06-05.
//

import CoreImage
import Foundation
import Metal
import CoreImage.CIFilterBuiltins

class SnowTextureFilter {
    typealias Error = TextureFilterError
    var intensity: Float = 0.5
    var anisotropy: Float = 0.5
    var bandwidthScale: Float = 1.0
    private let device: MTLDevice
    private let library: MTLLibrary
    private let ciContext: CIContext
    private let pipelineCache: MetalPipelineCache
    private let randomImageGenerator = CIFilter.randomGenerator()
    private var rng = SystemRandomNumberGenerator()
    
    init(device: MTLDevice, library: MTLLibrary, ciContext: CIContext, pipelineCache: MetalPipelineCache) {
        self.device = device
        self.library = library
        self.ciContext = ciContext
        self.pipelineCache = pipelineCache
    }

    private var uniformRandomTexture: MTLTexture?
    private var geoRandomTexture: MTLTexture?
    
    func run(inputTexture: MTLTexture, outputTexture: MTLTexture, commandBuffer: MTLCommandBuffer) throws {
        let randX: UInt64 = rng.next(upperBound: 500)
        let randY: UInt64 = rng.next(upperBound: 500)
        let needsUpdate: Bool
        if let uniformRandomTexture {
            needsUpdate = !(uniformRandomTexture.width == inputTexture.width && uniformRandomTexture.height == inputTexture.height)
        } else {
            needsUpdate = true
        }
        if needsUpdate {
            let randomTextures = Array(IIRTextureFilter.textures(from: inputTexture, device: device).prefix(2))
            self.uniformRandomTexture = randomTextures[0]
            self.geoRandomTexture = randomTextures[1]
        }
        guard let uniformRandomTexture, let geoRandomTexture else {
            throw Error.cantMakeTexture
        }
        
        guard let uniformRandomImage = randomImageGenerator
            .outputImage?
            .transformed(
                by: .init(
                    translationX: CGFloat(randX),
                    y: CGFloat(randY)
                )
            )
                .cropped(
                    to: CGRect(
                        origin: .zero,
                        size: CGSize(
                            width: inputTexture.width,
                            height: inputTexture.height
                        )
                    )
                ) else {
            throw Error.cantMakeRandomImage
        }
        // render RGB uniform to uniformRandomTexture
        ciContext.render(uniformRandomImage, to: uniformRandomTexture, commandBuffer: commandBuffer, bounds: uniformRandomImage.extent, colorSpace: ciContext.workingColorSpace ?? CGColorSpaceCreateDeviceRGB())
        
        let geoPipelineState: MTLComputePipelineState = try pipelineCache.pipelineState(function: .geometricDistribution)
        guard let geoEncoder = commandBuffer.makeComputeCommandEncoder() else {
            throw Error.cantMakeComputeEncoder
        }
        geoEncoder.setComputePipelineState(geoPipelineState)
        geoEncoder.setTexture(uniformRandomTexture, index: 0)
        geoEncoder.setTexture(geoRandomTexture, index: 1)
        var probablility: Float16 = 0.5
        geoEncoder.setBytes(&probablility, length: MemoryLayout<Float16>.size, index: 0)
        geoEncoder.dispatchThreads(textureWidth: inputTexture.width, textureHeight: inputTexture.height)
        // render RGB geo to geo random texture
        geoEncoder.endEncoding()
        
        let convertToYIQPipelineState: MTLComputePipelineState = try pipelineCache.pipelineState(function: .convertToYIQ)
        guard let yiqEncoder = commandBuffer.makeComputeCommandEncoder() else {
            throw Error.cantMakeComputeEncoder
        }
        yiqEncoder.setComputePipelineState(convertToYIQPipelineState)
        yiqEncoder.setTexture(geoRandomTexture, index: 0)
        yiqEncoder.setTexture(uniformRandomTexture, index: 1)
        yiqEncoder.dispatchThreads(textureWidth: geoRandomTexture.width, textureHeight: geoRandomTexture.height)
        // render yiq geo to uniform random texture
        yiqEncoder.endEncoding()
        
        let snowPipelineState: MTLComputePipelineState = try pipelineCache.pipelineState(function: .snow)
        
        guard let commandEncoder = commandBuffer.makeComputeCommandEncoder() else {
            throw Error.cantMakeComputeEncoder
        }
        commandEncoder.setComputePipelineState(snowPipelineState)
        commandEncoder.setTexture(inputTexture, index: 0)
        commandEncoder.setTexture(uniformRandomTexture, index: 1)
        commandEncoder.setTexture(outputTexture, index: 2)
        var intensity = intensity
        commandEncoder.setBytes(&intensity, length: MemoryLayout<Float>.size, index: 0)
        var anisotropy = anisotropy
        commandEncoder.setBytes(&anisotropy, length: MemoryLayout<Float>.size, index: 1)
        var bandwidthScale = bandwidthScale
        commandEncoder.setBytes(&bandwidthScale, length: MemoryLayout<Float>.size, index: 2)
        commandEncoder.dispatchThreads(textureWidth: inputTexture.width, textureHeight: inputTexture.height)
        commandEncoder.endEncoding()
    }
    
}
