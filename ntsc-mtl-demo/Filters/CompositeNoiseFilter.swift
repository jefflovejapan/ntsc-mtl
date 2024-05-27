//
//  CompositeNoiseFilter.swift
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-05-27.
//

import Foundation
import CoreImage

class CompositeNoiseFilter: CIFilter {
    static let kernel = loadKernel()
    var inputImage: CIImage?
    var noise: FBMNoiseSettings?
    var lacunarity: Float = 2
    private var rng = SystemRandomNumberGenerator()
    private let lumaComposeFilter = ComposeLumaFilter()
    
    private static func loadKernel() -> CIColorKernel {
        let url = Bundle.main.url(forResource: "default", withExtension: "metallib")!
        let data = try! Data(contentsOf: url)
        return try! CIColorKernel(functionName: "FractalNoise", fromMetalLibraryData: data)
    }
    
    override var outputImage: CIImage? {
        guard let inputImage, let noise else { return nil }
        let offset: UInt64 = rng.next()
        guard let noised = Self.kernel.apply(
            extent: inputImage.extent,
            arguments: [
                inputImage,
                noise.frequency,
                noise.intensity,
                noise.detail.clamped(within: 1...5),
                lacunarity,
                Float(offset)
            ]
        ) else { return nil }
        lumaComposeFilter.yImage = noised
        lumaComposeFilter.iqImage = inputImage
        return lumaComposeFilter.outputImage
    }
}
