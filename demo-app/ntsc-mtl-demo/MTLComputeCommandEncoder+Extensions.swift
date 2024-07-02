//
//  MTLComputeCommandEncoder+Extensions.swift
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-06-12.
//

import Foundation
import Metal

extension MTLComputeCommandEncoder {
    func dispatchThreads(
        textureWidth: Int,
        textureHeight: Int,
        threadgroupScale: Int = 8
    ) {
        dispatchThreads(MTLSize(
            width: textureWidth,
            height: textureHeight,
            depth: 1
        ), threadsPerThreadgroup: MTLSize(
            width: threadgroupScale,
            height: threadgroupScale,
            depth: 1
        )
        )
    }
}
