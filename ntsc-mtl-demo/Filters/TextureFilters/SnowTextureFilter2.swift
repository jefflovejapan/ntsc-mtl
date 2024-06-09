//
//  SnowTextureFilter2.swift
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-06-09.
//

import CoreImage
import Foundation
import Metal

class SnowTextureFilter2 {
    typealias Error = TextureFilterError
    var intensity: Float = 0.5
    var anisotropy: Float = 0.5
    var bandwidthScale: Float = 1.0
    private let device: MTLDevice
    private let library: MTLLibrary
    private let ciContext: CIContext
    private let pipelineCache: MetalPipelineCache
    
    private var randomTexture: MTLTexture?

    init(device: MTLDevice, library: MTLLibrary, ciContext: CIContext, pipelineCache: MetalPipelineCache) {
        self.device = device
        self.library = library
        self.ciContext = ciContext
        self.pipelineCache = pipelineCache
    }
    
    func run(inputTexture: MTLTexture, outputTexture: MTLTexture, commandBuffer: MTLCommandBuffer) throws {
        let rnd: MTLTexture
        if let randomTexture {
            rnd = randomTexture
        } else {
            let descriptor = MTLTextureDescriptor.textureBufferDescriptor(with: inputTexture.pixelFormat, width: 200, usage: [.shaderRead, .shaderWrite])
            guard let texture = device.makeTexture(descriptor: descriptor) else {
                throw Error.cantMakeTexture
            }
            rnd = texture
            self.randomTexture = texture
        }
        guard let rndEncoder = commandBuffer.makeComputeCommandEncoder() else {
            throw Error.cantMakeComputeEncoder
        }
        
        rndEncoder.setComputePipelineState(try pipelineCache.pipelineState(function: .geometricDistribution))
        rndEncoder.setTexture(rnd, index: 0)
        rndEncoder.dispatchThreads(MTLSize(width: rnd.width, height: rnd.height, depth: 1), threadsPerThreadgroup: MTLSize(width: 8, height: 8, depth: 1))
        rndEncoder.endEncoding()
        
        guard let snowEncoder = commandBuffer.makeComputeCommandEncoder() else {
            throw Error.cantMakeComputeEncoder
        }
                
        snowEncoder.setComputePipelineState(try pipelineCache.pipelineState(function: .snow2))
        snowEncoder.setTexture(inputTexture, index: 0)
        snowEncoder.setTexture(rnd, index: 1)
        snowEncoder.setTexture(outputTexture, index: 2)
        var bandwidthScale = bandwidthScale
        snowEncoder.setBytes(&bandwidthScale, length: MemoryLayout<Float>.size, index: 0)
        snowEncoder.dispatchThreads(MTLSize(width: inputTexture.width, height: inputTexture.height, depth: 1), threadsPerThreadgroup: MTLSize(width: 8, height: 8, depth: 1))
        snowEncoder.endEncoding()
    }
}
