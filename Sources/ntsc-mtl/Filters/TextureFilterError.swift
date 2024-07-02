//
//  TextureFilterError.swift
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-06-23.
//

import Foundation

public enum TextureFilterError: Swift.Error {
    case cantMakeTexture
    case cantMakeCommandQueue
    case cantMakeCommandBuffer
    case cantMakeComputeEncoder
    case cantMakeLibrary
    case cantMakeRandomImage
    case cantMakeFilter(String)
    case cantMakeFunction(String)
    case cantMakeBlitEncoder
    case logicHole(String)
    case notImplemented
}
