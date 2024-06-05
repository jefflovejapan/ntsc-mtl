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
        self.blurKernel = MPSImageBox(device: device, kernelWidth: 99, kernelHeight: 99)
        self.library = library
    }
    
    private var yiqComposepipelineState: MTLComputePipelineState?
    
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
        
        guard let blitEncoder = commandBuffer.makeBlitCommandEncoder() else {
            throw Error.cantMakeBlitEncoder
        }
        
        blitEncoder.copy(
            from: outputTexture,
            sourceSlice: 0,
            sourceLevel: 0,
            to: scratchTexture,
            destinationSlice: 0,
            destinationLevel: 0,
            sliceCount: outputTexture.arrayLength,
            levelCount: outputTexture.mipmapLevelCount
        )

        blitEncoder.endEncoding()
        
        // We've blurred the YIQ "image" in scratchTexture
        self.blurKernel.encode(commandBuffer: commandBuffer, inPlaceTexture: &scratchTexture)
        let pipelineState: MTLComputePipelineState
        if let yiqComposepipelineState {
            pipelineState = yiqComposepipelineState
        } else {
            let composeFunctionName = "yiqCompose"
            guard let function = library.makeFunction(name: composeFunctionName) else {
                throw Error.cantMakeFunction(composeFunctionName    )
            }
            
            pipelineState = try device.makeComputePipelineState(function: function)
            self.yiqComposepipelineState = pipelineState
        }
        
        guard let composeCommandEncoder = commandBuffer.makeComputeCommandEncoder() else {
            throw Error.cantMakeComputeEncoder
        }
        composeCommandEncoder.setComputePipelineState(pipelineState)
        composeCommandEncoder.setTexture(scratchTexture, index: 0)
        composeCommandEncoder.setTexture(inputTexture, index: 1)
        composeCommandEncoder.setTexture(outputTexture, index: 2)
        let yChannel: YIQChannels = .y
        var channelMix = yChannel.floatMix
        composeCommandEncoder.setBytes(&channelMix, length: MemoryLayout.size(ofValue: channelMix), index: 0)
        composeCommandEncoder.dispatchThreads(
            MTLSize(width: outputTexture.width, height: outputTexture.height, depth: 1),
            threadsPerThreadgroup: MTLSize(width: 8, height: 8, depth: 1))
        composeCommandEncoder.endEncoding()
    }
}
