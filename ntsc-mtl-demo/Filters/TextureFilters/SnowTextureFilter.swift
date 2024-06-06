//
//  SnowTextureFilter.swift
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-06-05.
//

import CoreImage
import Foundation
import Metal

class SnowTextureFilter {
    typealias Error = TextureFilterError
    var intensity: Float = 0.5
    var anisotropy: Float = 0.5
    var bandwidthScale: Float = 1.0
    private let device: MTLDevice
    private let library: MTLLibrary
    private let ciContext: CIContext
    
    init(device: MTLDevice, library: MTLLibrary, ciContext: CIContext) {
        self.device = device
        self.library = library
        self.ciContext = ciContext
    }
    
    private var rng = SystemRandomNumberGenerator()
    private let randomFilter = CIFilter.randomGenerator()
    private var snowPipelineState: MTLComputePipelineState?
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
        
        let pipelineState: MTLComputePipelineState
        if let snowPipelineState {
            pipelineState = snowPipelineState
        } else {
            let functionName = "snow"
            guard let function = library.makeFunction(name: functionName) else {
                throw Error.cantMakeFunction(functionName)
            }
            pipelineState = try device.makeComputePipelineState(function: function)
            self.snowPipelineState = pipelineState
        }
        
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
