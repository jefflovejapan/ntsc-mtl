//
//  NoiseFilter.swift
//  
//
//  Created by Jeffrey Blagdon on 2024-07-11.
//

import CoreImage
import Foundation
import Metal
import SimplexNoiseFilter

class NoiseFilter {
    typealias Error = TextureFilterError
    private let device: MTLDevice
    private let pipelineCache: MetalPipelineCache
    private let ciContext: CIContext
    private let noiseGenerator = SimplexNoiseFilter.SimplexNoiseGenerator()
    var zoom: Float{
        get {
            noiseGenerator.zoom
        }
        set {
            noiseGenerator.zoom = newValue
        }
    }
    var contrast: Float {
        get {
            noiseGenerator.contrast
        }
        set {
            noiseGenerator.contrast = newValue
        }
    }
    private var tex: MTLTexture?
    private var rng = SystemRandomNumberGenerator()
    
    init(device: MTLDevice, pipelineCache: MetalPipelineCache, ciContext: CIContext) {
        self.device = device
        self.pipelineCache = pipelineCache
        self.ciContext = ciContext
    }
    
    func run(input: MTLTexture, output: MTLTexture, commandBuffer: MTLCommandBuffer) throws {
        let needsUpdate: Bool
        if let tex {
            needsUpdate = !(tex.width == input.width && tex.height == input.height)
        } else {
            needsUpdate = true
        }
        
        if needsUpdate {
            tex = Texture.texture(from: input, device: device)
        }
        guard let tex else {
            throw Error.cantMakeTexture
        }
        let randX: UInt64 = rng.next(upperBound: 500)
        let randY: UInt64 = rng.next(upperBound: 500)
        
        noiseGenerator.offsetX = Float(randX)
        noiseGenerator.offsetY = Float(randY)
        
        guard let noise = noiseGenerator.outputImage?.cropped(to: CGRect(origin: .zero, size: CGSize(width: CGFloat(input.width), height: CGFloat(input.height)))) else {
            throw Error.cantMakeNoise
        }
        
        ciContext.render(noise, to: tex, commandBuffer: commandBuffer, bounds: noise.extent, colorSpace: ciContext.workingColorSpace ?? CGColorSpaceCreateDeviceRGB())
        
        try encodeKernelFunction(.noise, pipelineCache: pipelineCache, textureWidth: input.width, textureHeight: input.height, commandBuffer: commandBuffer, encode: { encoder in
            encoder.setTexture(input, index: 0)
            encoder.setTexture(tex, index: 1)
            encoder.setTexture(output, index: 2)
        })
    }
}
