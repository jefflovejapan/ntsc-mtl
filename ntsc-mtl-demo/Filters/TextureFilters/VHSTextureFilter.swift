//
//  VHSTextureFilter.swift
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-06-04.
//

import Foundation
import Metal

class VHSTextureFilter {
    typealias Error = IIRTextureFilter.Error
    
    private let device: MTLDevice
    private let pipelineCache: MetalPipelineCache
    var settings: VHSSettings = .default
    
    init(device: MTLDevice, pipelineCache: MetalPipelineCache) {
        self.device = device
        self.pipelineCache = pipelineCache
    }
    
    required init?(coder: NSCoder) {
        fatalError("Not implemented")
    }
    
    func run(inputTexture: MTLTexture, outputTexture: MTLTexture, commandBuffer: MTLCommandBuffer) throws {
        try justBlit(from: inputTexture, to: outputTexture, commandBuffer: commandBuffer)
    }
}
