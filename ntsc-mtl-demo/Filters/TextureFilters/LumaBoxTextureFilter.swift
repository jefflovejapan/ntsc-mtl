//
//  LumaBoxTextureFilter.swift
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-06-04.
//

import Foundation
import Metal
import MetalPerformanceShaders

class LumaBoxTextureFilter {
    typealias Error = TextureFilterError
    
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let blurKernel: MPSImageBox
    private let library: MTLLibrary
    private var scratchTexture: MTLTexture?
    
    init(device: MTLDevice, commandQueue: MTLCommandQueue, library: MTLLibrary) {
        self.device = device
        self.commandQueue = commandQueue
        self.blurKernel = MPSImageBox(device: device, kernelWidth: 5, kernelHeight: 5)
        self.library = library
    }
    
    private var yiqComposePipelineState: MTLComputePipelineState?
    
    func run(inputTexture: MTLTexture, outputTexture: MTLTexture, commandBuffer: MTLCommandBuffer) throws {
        let needsUpdate: Bool
        if let scratchTexture {
            needsUpdate = !(scratchTexture.width == outputTexture.width && scratchTexture.height == outputTexture.height)
        } else {
            needsUpdate = true
        }
        var scratchTexture: MTLTexture
        if needsUpdate {
            let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: outputTexture.pixelFormat,
                width: outputTexture.width,
                height: outputTexture.height,
                mipmapped: false
            )
            textureDescriptor.usage = [.shaderRead, .shaderWrite, .renderTarget]
            guard let texture = device.makeTexture(descriptor: textureDescriptor) else {
                throw Error.cantInstantiateTexture
            }
            scratchTexture = texture
        } else {
            guard let tex = self.scratchTexture else {
                throw Error.logicHole("Fell through LumaBox needsUpdate logic")
            }
            scratchTexture = tex
        }
        self.scratchTexture = scratchTexture
        
        // We've blurred the YIQ "image" in scratchTexture
        self.blurKernel.encode(commandBuffer: commandBuffer, sourceTexture: inputTexture, destinationTexture: scratchTexture)
        let pipelineState: MTLComputePipelineState
        if let yiqComposePipelineState {
            pipelineState = yiqComposePipelineState
        } else {
            let composeFunctionName = "yiqCompose"
            guard let function = library.makeFunction(name: composeFunctionName) else {
                throw Error.cantMakeFunction(composeFunctionName    )
            }
            
            pipelineState = try device.makeComputePipelineState(function: function)
            self.yiqComposePipelineState = pipelineState
        }
        
        guard let composeCommandEncoder = commandBuffer.makeComputeCommandEncoder() else {
            throw Error.cantMakeComputeEncoder
        }
        composeCommandEncoder.setComputePipelineState(pipelineState)
        composeCommandEncoder.setTexture(scratchTexture, index: 0)
        composeCommandEncoder.setTexture(inputTexture, index: 1)
        composeCommandEncoder.setTexture(outputTexture, index: 2)
        let yChannel: YIQChannels = .y
        var channelMix: [Float16] = yChannel.floatMix
        composeCommandEncoder.setBytes(&channelMix, length: MemoryLayout<Float16>.size * 4, index: 0)
        composeCommandEncoder.dispatchThreads(
            MTLSize(width: outputTexture.width, height: outputTexture.height, depth: 1),
            threadsPerThreadgroup: MTLSize(width: 8, height: 8, depth: 1))
        composeCommandEncoder.endEncoding()
    }
}
