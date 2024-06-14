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
    private let ciContext: CIContext
    private let pipelineCache: MetalPipelineCache
    private let randomImageGenerator = CIFilter.randomGenerator()
    private var rng = SystemRandomNumberGenerator()
    
    init(device: MTLDevice, ciContext: CIContext, pipelineCache: MetalPipelineCache) {
        self.device = device
        self.ciContext = ciContext
        self.pipelineCache = pipelineCache
    }

    private var uniformRandomTexture: MTLTexture?
    private var geoRandomTexture: MTLTexture?
    private var snowIntensityTexture: MTLTexture?
    
    func run(inputTexture: MTLTexture, outputTexture: MTLTexture, commandBuffer: MTLCommandBuffer) throws {
        let needsUpdate: Bool
        if let uniformRandomTexture {
            needsUpdate = !(uniformRandomTexture.width == inputTexture.width && uniformRandomTexture.height == inputTexture.height)
        } else {
            needsUpdate = true
        }
        if needsUpdate {
            let randomTextures = Array(IIRTextureFilter.textures(from: inputTexture, device: device).prefix(3))
            self.uniformRandomTexture = randomTextures[0]
            self.geoRandomTexture = randomTextures[1]
            self.snowIntensityTexture = randomTextures[2]
        }
        guard let uniformRandomTexture, let geoRandomTexture, let snowIntensityTexture else {
            throw Error.cantMakeTexture
        }
        
        try writeUniformRandom(to: uniformRandomTexture, commandBuffer: commandBuffer)
//        try transformUniformRandom(uniformRandomTexture, toSnowIntensity: snowIntensityTexture, commandBuffer: commandBuffer)
        try applySnow(
            inputTexture: inputTexture,
            uniformRandomTexture: uniformRandomTexture,
//            snowIntensityTexture: uniformRandomTexture,
            outputTexture: outputTexture,
            commandBuffer: commandBuffer
        )
    }
    
    private func writeUniformRandom(to texture: MTLTexture, commandBuffer: MTLCommandBuffer) throws {
        let randX: UInt64 = rng.next(upperBound: 500)
        let randY: UInt64 = rng.next(upperBound: 500)
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
                            width: texture.width,
                            height: texture.height
                        )
                    )
                ) else {
            throw Error.cantMakeRandomImage
        }
        // render RGB uniform to uniformRandomTexture
        ciContext.render(uniformRandomImage, to: texture, commandBuffer: commandBuffer, bounds: uniformRandomImage.extent, colorSpace: ciContext.workingColorSpace ?? CGColorSpaceCreateDeviceRGB())
    }
    
    private func transformUniformRandom(_ uniformRandomTexture: MTLTexture, toSnowIntensity snowIntensityTexture: MTLTexture, commandBuffer: MTLCommandBuffer) throws {
        let pipelineState: MTLComputePipelineState = try pipelineCache.pipelineState(function: .snowIntensity)
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw Error.cantMakeComputeEncoder
        }
        encoder.setComputePipelineState(pipelineState)
        encoder.setTexture(uniformRandomTexture, index: 0)
        encoder.setTexture(snowIntensityTexture, index: 1)
        var intensity = intensity
        encoder.setBytes(&intensity, length: MemoryLayout<Float16>.size, index: 0)
        var anisotropy = anisotropy
        encoder.setBytes(&anisotropy, length: MemoryLayout<Float16>.size, index: 1)
        encoder.dispatchThreads(textureWidth: uniformRandomTexture.width, textureHeight: uniformRandomTexture.height)
        encoder.endEncoding()
    }
    
    private func transform(uniform: MTLTexture, toGeometric geometric: MTLTexture, commandBuffer: MTLCommandBuffer) throws {
        let geoPipelineState: MTLComputePipelineState = try pipelineCache.pipelineState(function: .geometricDistribution)
        guard let geoEncoder = commandBuffer.makeComputeCommandEncoder() else {
            throw Error.cantMakeComputeEncoder
        }
        geoEncoder.setComputePipelineState(geoPipelineState)
        geoEncoder.setTexture(uniform, index: 0)
        geoEncoder.setTexture(geometric, index: 1)
        var probablility: Float16 = 0.5
        geoEncoder.setBytes(&probablility, length: MemoryLayout<Float16>.size, index: 0)
        geoEncoder.dispatchThreads(textureWidth: uniform.width, textureHeight: uniform.height)
        geoEncoder.endEncoding()
    }
    
    private func transform(geometric: MTLTexture, toYIQ yiq: MTLTexture, commandBuffer: MTLCommandBuffer) throws {
        let convertToYIQPipelineState: MTLComputePipelineState = try pipelineCache.pipelineState(function: .convertToYIQ)
        guard let yiqEncoder = commandBuffer.makeComputeCommandEncoder() else {
            throw Error.cantMakeComputeEncoder
        }
        yiqEncoder.setComputePipelineState(convertToYIQPipelineState)
        yiqEncoder.setTexture(geometric, index: 0)
        yiqEncoder.setTexture(yiq, index: 1)
        yiqEncoder.dispatchThreads(textureWidth: geometric.width, textureHeight: geometric.height)
        // render yiq geo to uniform random texture
        yiqEncoder.endEncoding()
    }
    
    private func applySnow(
        inputTexture: MTLTexture,
        uniformRandomTexture: MTLTexture,
//        snowIntensityTexture: MTLTexture,
        outputTexture: MTLTexture,
        commandBuffer: MTLCommandBuffer
    ) throws {
        let snowPipelineState: MTLComputePipelineState = try pipelineCache.pipelineState(function: .snow)
        guard let commandEncoder = commandBuffer.makeComputeCommandEncoder() else {
            throw Error.cantMakeComputeEncoder
        }
        commandEncoder.setComputePipelineState(snowPipelineState)
        commandEncoder.setTexture(inputTexture, index: 0)
        commandEncoder.setTexture(uniformRandomTexture, index: 1)
//        commandEncoder.setTexture(snowIntensityTexture, index: 2)
        commandEncoder.setTexture(outputTexture, index: 2)
        var bandwidthScale = bandwidthScale
        commandEncoder.setBytes(&bandwidthScale, length: MemoryLayout<Float>.size, index: 0)
        commandEncoder.dispatchThreads(textureWidth: inputTexture.width, textureHeight: inputTexture.height)
        commandEncoder.endEncoding()
    }
}
