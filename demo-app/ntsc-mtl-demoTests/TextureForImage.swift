//
//  TextureForImage.swift
//  ntsc-mtl-demoTests
//
//  Created by Jeffrey Blagdon on 2024-06-08.
//

import Foundation
import Metal
import XCTest

func textureForImage(_ image: CIImage, device: MTLDevice, line: UInt = #line) throws -> MTLTexture {
    let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba16Float, width: Int(image.extent.width), height: Int(image.extent.height), mipmapped: false)
    return try XCTUnwrap(device.makeTexture(descriptor: descriptor), line: line)
}
