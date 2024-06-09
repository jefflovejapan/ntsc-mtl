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
    
    init(noise: FBMNoiseSettings?, device: MTLDevice, library: MTLLibrary, ciContext: CIContext, pipelineCache: MetalPipelineCache) {
        self.noise = noise
        self.device = device
        self.library = library
        self.ciContext = ciContext
        self.pipelineCache = pipelineCache
    }
    
    func run(inputTexture: MTLTexture, outputTexture: MTLTexture, commandBuffer: MTLCommandBuffer) throws {
        let nextX: UInt8 = rng.next(upperBound: 100)
        let nextY: UInt8 = rng.next(upperBound: 100)
        simplexNoise.offsetX = Float(nextX)
        simplexNoise.offsetY = Float(nextY)
        guard let noise = simplexNoise.outputImage else {
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
            throw Error.cantInstantiateTexture
        }
        
        ciContext.render(noise, to: simplexNoiseTexture, commandBuffer: commandBuffer, bounds: CGRect(x: 0, y: 0, width: CGFloat(inputTexture.width), height: CGFloat(inputTexture.height)), colorSpace: ciContext.workingColorSpace ?? CGColorSpaceCreateDeviceRGB())
        guard let commandEncoder = commandBuffer.makeComputeCommandEncoder() else {
            throw Error.cantMakeComputeEncoder
        }
        let pipelineState: MTLComputePipelineState = try pipelineCache.pipelineState(function: .multiplyLuma)
        commandEncoder.setComputePipelineState(pipelineState)
        commandEncoder.setTexture(inputTexture, index: 0)
        commandEncoder.setTexture(simplexNoiseTexture, index: 1)
        commandEncoder.setTexture(outputTexture, index: 2)
        var intensity = self.noise?.intensity ?? Self.defaultIntensity
        commandEncoder.setBytes(&intensity, length: MemoryLayout<Float16>.size, index: 0)
        commandEncoder.dispatchThreads(
            MTLSize(width: inputTexture.width, height: inputTexture.height, depth: 1),
            threadsPerThreadgroup: MTLSize(width: 8, height: 8, depth: 1)
        )
        commandEncoder.endEncoding()
    }
    
}
