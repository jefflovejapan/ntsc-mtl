//
//  YIQ.swift
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-05-31.
//

import Foundation
import simd

// Define the matrices using SIMD types
public let yiqToRgbMatrix = float3x3([
    SIMD3<Float>(1.0, 1.0, 1.0),
    SIMD3<Float>(0.956, -0.272, -1.106),
    SIMD3<Float>(0.619, -0.647, 1.703)
])

public let rgbToYiqMatrix = float3x3([
    SIMD3<Float>(0.299, 0.5959, 0.2115),
    SIMD3<Float>(0.587, -0.2746, -0.5227),
    SIMD3<Float>(0.114, -0.3213, 0.3112)
])

// Convert RGB to YIQ
public func toYIQ(rgba: SIMD4<Float>) -> SIMD4<Float> {
    let rgb = SIMD3<Float>(rgba.x, rgba.y, rgba.z)
    let yiq = rgbToYiqMatrix * rgb
    return SIMD4<Float>(yiq.x, yiq.y, yiq.z, rgba.w)
}

// Convert YIQ to RGB
public func toRGB(yiqa: SIMD4<Float>) -> SIMD4<Float> {
    let yiq = SIMD3<Float>(yiqa.x, yiqa.y, yiqa.z)
    let rgb = yiqToRgbMatrix * yiq
    return SIMD4<Float>(rgb.x, rgb.y, rgb.z, yiqa.w)
}
