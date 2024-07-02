//
//  JustBlit.swift
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-06-10.
//

import Foundation
import Metal

func justBlit(from fromTexture: MTLTexture, to toTexture: MTLTexture, commandBuffer: MTLCommandBuffer) throws {
    guard let blitEncoder = commandBuffer.makeBlitCommandEncoder() else {
        throw TextureFilterError.cantMakeBlitEncoder
    }
    blitEncoder.copy(from: fromTexture, to: toTexture)
    blitEncoder.endEncoding()
}
