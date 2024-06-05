//
//  MTLTexture+Extensions.swift
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-06-05.
//

import Foundation
import Metal

extension MTLTexture {
    func pixelValue(x: Int, y: Int) -> [Float] {
        var value: [Float] = [0, 0, 0, 0]
        let bytesPerRow = 4 * MemoryLayout<Float>.size * self.width
        let region = MTLRegionMake2D(x, y, 1, 1)
        self.getBytes(&value, bytesPerRow: bytesPerRow, from: region, mipmapLevel: 0)
        return value
    }
    
    func paint(with value: [Float]) {
        var value = value
        let bytesPerRow = 4 * MemoryLayout<Float>.size * self.width
        let region = MTLRegionMake2D(0, 0, self.width, self.height)
        self.replace(region: region, mipmapLevel: 0, withBytes: &value, bytesPerRow: bytesPerRow)
    }
}
