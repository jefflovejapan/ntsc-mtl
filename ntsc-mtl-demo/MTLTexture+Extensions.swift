//
//  MTLTexture+Extensions.swift
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-06-05.
//

import Foundation
import Metal
import CoreImage
import XCTest

extension MTLTexture {
    func pixelValue(x: Int, y: Int) -> [Float16] {
        var value: [Float16] = [0, 0, 0, 0]
        let bytesPerRow = 4 * MemoryLayout<Float16>.size * self.width
        let region = MTLRegionMake2D(x, y, 1, 1)
        self.getBytes(&value, bytesPerRow: bytesPerRow, from: region, mipmapLevel: 0)
        return value
    }
}
