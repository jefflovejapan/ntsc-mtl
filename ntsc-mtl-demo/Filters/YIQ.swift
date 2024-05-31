//
//  YIQ.swift
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-05-31.
//

import Foundation
import simd

// Define the matrices using SIMD types
let yiqToRgbMatrix = float3x3([
    SIMD3<Float>(1.0, 0.9563, 0.6210),
    SIMD3<Float>(1.0, -0.2721, -0.6474),
    SIMD3<Float>(1.0, -1.1070, 1.7046)
])

let rgbToYiqMatrix = float3x3([
    SIMD3<Float>(0.299, 0.587, 0.114),
    SIMD3<Float>(0.595716, -0.274453, -0.321263),
    SIMD3<Float>(0.211456, -0.522591, 0.311135)
])

// Convert RGB to YIQ
func toYIQ(rgba: SIMD4<Float>) -> SIMD4<Float> {
    let rgb = SIMD3<Float>(rgba.x, rgba.y, rgba.z)
    let yiq = rgbToYiqMatrix * rgb
    return SIMD4<Float>(yiq.x, yiq.y, yiq.z, rgba.w)
}

// Convert YIQ to RGB
func toRGB(yiqa: SIMD4<Float>) -> SIMD4<Float> {
    let yiq = SIMD3<Float>(yiqa.x, yiqa.y, yiqa.z)
    let rgb = yiqToRgbMatrix * yiq
    return SIMD4<Float>(rgb.x, rgb.y, rgb.z, yiqa.w)
}
