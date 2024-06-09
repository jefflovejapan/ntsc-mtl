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
    
    init(device: MTLDevice, library: MTLLibrary, ciContext: CIContext, pipelineCache: MetalPipelineCache) {
        self.device = device
        self.library = library
        self.ciContext = ciContext
        self.pipelineCache = pipelineCache
    }
    
    private var rng = SystemRandomNumberGenerator()
    private let randomFilter = CIFilter.randomGenerator()
    private var randomTexture: MTLTexture?
    
    func run(inputTexture: MTLTexture, outputTexture: MTLTexture, commandBuffer: MTLCommandBuffer) throws {
        guard let randomImage = self.randomFilter.outputImage else {
            throw Error.cantInstantiateTexture
        }
        
        let needsUpdate: Bool
        if let randomTexture {
            needsUpdate = !(randomTexture.width == inputTexture.width && randomTexture.height == inputTexture.height)
        } else {
            needsUpdate = true
        }
        if needsUpdate {
            guard let randomTexture = IIRTextureFilter.texture(from: inputTexture, device: device) else {
                throw Error.cantInstantiateTexture
            }
            self.randomTexture = randomTexture
        }
        guard let randomTexture else {
            throw Error.cantInstantiateTexture
        }
        
        ciContext.render(randomImage, to: randomTexture, commandBuffer: commandBuffer, bounds: CGRect(x: 0, y: 0, width: inputTexture.width, height: inputTexture.height), colorSpace: ciContext.workingColorSpace ?? CGColorSpaceCreateDeviceRGB())
        
        let pipelineState: MTLComputePipelineState = try pipelineCache.pipelineState(function: .snow)
        
        guard let commandEncoder = commandBuffer.makeComputeCommandEncoder() else {
            throw Error.cantMakeComputeEncoder
        }
        commandEncoder.setComputePipelineState(pipelineState)
        commandEncoder.dispatchThreads(
            MTLSize(
                width: inputTexture.width,
                height: inputTexture.height,
                depth: 1
            ),
            threadsPerThreadgroup: MTLSize(
                width: 8,
                height: 8,
                depth: 1
            )
        )
        commandEncoder.endEncoding()
    }
    
}
