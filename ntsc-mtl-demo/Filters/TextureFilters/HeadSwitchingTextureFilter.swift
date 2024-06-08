//
//  HeadSwitchingTextureFilter.swift
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-06-07.
//

import Foundation
import Metal
import CoreImage

class HeadSwitchingTextureFilter {
    typealias Error = TextureFilterError
    private let device: MTLDevice
    private let library: MTLLibrary
    private let context: CIContext
    var headSwitchingSettings: HeadSwitchingSettings?
    init(device: MTLDevice, library: MTLLibrary, ciContext: CIContext) {
        self.device = device
        self.library = library
        self.context = ciContext
    }
    
    func run(inputTexture: MTLTexture, outputTexture: MTLTexture, commandBuffer: MTLCommandBuffer) throws {
        guard let headSwitchingSettings else {
            try justBlit(inputTexture: inputTexture, outputTexture: outputTexture, commandBuffer: commandBuffer)
            return
        }
        fatalError("Not implemented -- \(headSwitchingSettings as Optional)")
    }
    
    private func justBlit(inputTexture: MTLTexture, outputTexture: MTLTexture, commandBuffer: MTLCommandBuffer) throws {
        guard let blitEncoder = commandBuffer.makeBlitCommandEncoder() else {
            throw Error.cantMakeBlitEncoder
        }
        blitEncoder.copy(from: inputTexture, to: outputTexture)
        blitEncoder.endEncoding()
    }
}
