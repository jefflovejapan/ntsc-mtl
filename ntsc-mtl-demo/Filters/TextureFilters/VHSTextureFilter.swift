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
    private let lumaFilter: IIRTextureFilter
    private let chromaFilter: IIRTextureFilter
    private let lumaFilterSingle: IIRTextureFilter
    private var rng = SystemRandomNumberGenerator()
    var bandwidthScale: Float = NTSCEffect.default.bandwidthScale
    var settings: VHSSettings = .default
    var filterType: FilterType = NTSCEffect.default.filterType
    
    init(device: MTLDevice, pipelineCache: MetalPipelineCache, ciContext: CIContext) {
        self.device = device
        self.pipelineCache = pipelineCache
        self.ciContext = ciContext
        self.lumaFilter = IIRTextureFilter(device: device, pipelineCache: pipelineCache, initialCondition: .zero, channels: .y, delay: 0)
        self.chromaFilter = IIRTextureFilter(device: device, pipelineCache: pipelineCache, initialCondition: .zero, channels: [.i, .q], delay: 0)
        self.lumaFilterSingle = IIRTextureFilter(device: device, pipelineCache: pipelineCache, initialCondition: .zero, channels: .y, delay: 0)
        self.lumaFilterSingle.scale = -1.6
    }
    
    required init?(coder: NSCoder) {
        fatalError("Not implemented")
    }
    
    private var textures: [MTLTexture] = []
    private static let texturesCount = 7
    
    func run(inputTexture: MTLTexture, outputTexture: MTLTexture, commandBuffer: MTLCommandBuffer) throws {
        let needsUpdate: Bool
        if let textureA = textures.first {
            needsUpdate = !(textureA.width == inputTexture.width && textureA.height == inputTexture.height)
        } else {
            needsUpdate = true
        }
        if needsUpdate {
            let textures = Array(IIRTextureFilter.textures(from: inputTexture, device: device).prefix(Self.texturesCount))
            self.textures = textures
        }
        guard textures.count == Self.texturesCount else {
            throw Error.cantMakeTexture
        }
        let iter = IteratorThing(vals: textures)
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
        if settings.tapeSpeedEnabled {
            try tapeSpeed(inputTexture: try iter.last, outputTexture: try iter.next(), textureA: try iter.next(), textureB: try iter.next(), textureC: try iter.next(), commandBuffer: commandBuffer)
        }
        try justBlit(from: try iter.last, to: outputTexture, commandBuffer: commandBuffer)
    }
    
    private func writeRandom(to texture: MTLTexture, commandBuffer: MTLCommandBuffer) throws {
        let randomX: UInt = rng.next(upperBound: 500)
        let randomY: UInt = rng.next(upperBound: 500)
        guard let randomImg = randomGenerator.outputImage?.transformed(by: .init(translationX: CGFloat(randomX), y: CGFloat(randomY))).cropped(to: CGRect(origin: .zero, size: CGSize(width: texture.width, height: texture.height))) else {
            throw Error.cantMakeRandomImage
        }
        
        ciContext.render(randomImg, to: texture, commandBuffer: commandBuffer, bounds: randomImg.extent, colorSpace: ciContext.workingColorSpace ?? CGColorSpaceCreateDeviceRGB())
    }
    
    private func tapeSpeed(inputTexture: MTLTexture, outputTexture: MTLTexture, textureA: MTLTexture, textureB: MTLTexture, textureC: MTLTexture, commandBuffer: MTLCommandBuffer) throws {
        try justBlit(from: inputTexture, to: outputTexture, commandBuffer: commandBuffer)
        return
        let params = settings.tapeSpeed.params
        let lumaFunction = ChromaLowpassTextureFilter.lowpassFilter(
            cutoff: params.lumaCut,
            rate: NTSC.rate * bandwidthScale,
            filterType: filterType)
        self.lumaFilter.numerators = lumaFunction.numerators
        self.lumaFilter.denominators = lumaFunction.denominators
        let chromaFunction = ChromaLowpassTextureFilter.lowpassFilter(cutoff: params.chromaCut, rate: NTSC.rate * bandwidthScale, filterType: filterType)
        self.chromaFilter.numerators = chromaFunction.numerators
        self.chromaFilter.denominators = chromaFunction.denominators
        self.chromaFilter.delay = params.chromaDelay
        
        try self.lumaFilter.run(inputTexture: inputTexture, outputTexture: textureA, commandBuffer: commandBuffer)
        try self.lumaFilterSingle.run(inputTexture: textureA, outputTexture: textureB, commandBuffer: commandBuffer)
        try self.chromaFilter.run(inputTexture: inputTexture, outputTexture: textureC, commandBuffer: commandBuffer)
        let pipelineState = try self.pipelineCache.pipelineState(function: .yiqCompose)
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw Error.cantMakeComputeEncoder
        }
        encoder.setComputePipelineState(pipelineState)
        encoder.setTexture(textureB, index: 0)
        encoder.setTexture(textureC, index: 1)
        encoder.setTexture(textureC, index: 2)
        encoder.setTexture(outputTexture, index: 3)
        encoder.dispatchThreads(textureWidth: inputTexture.width, textureHeight: inputTexture.height)
        encoder.endEncoding()
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
