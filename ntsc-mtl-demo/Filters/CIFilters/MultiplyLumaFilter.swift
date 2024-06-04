//
//  MultiplyLumaFilter.swift
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-05-27.
//

import Foundation
import CoreImage

class MultiplyLumaFilter: CIFilter {
    var mainImage: CIImage?
    var otherImage: CIImage?
    var intensity: Float = MultiplyLumaFilter.defaultIntensity
    static let defaultIntensity: Float = 0.05
    
    private static let kernel = loadKernel()
    private static func loadKernel() -> CIColorKernel {
        let url = Bundle.main.url(forResource: "default", withExtension: "metallib")!
        let data = try! Data(contentsOf: url)
        return try! CIColorKernel(functionName: "MultiplyLuma", fromMetalLibraryData: data)
    }
    
    override var outputImage: CIImage? {
        guard let mainImage, let otherImage else { return nil }
        return Self.kernel.apply(extent: mainImage.extent, arguments: [mainImage, otherImage, intensity])
    }
}
