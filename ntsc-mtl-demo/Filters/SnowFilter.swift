//
//  SnowFilter.swift
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-05-31.
//

import Foundation
import CoreImage
import CoreImage.CIFilterBuiltins

class SnowFilter: CIFilter {
    var inputImage: CIImage?
    var intensity: Float = 0.5
    var anisotropy: Float = 0.5
    var bandwidthScale: Float = 1.0
    private var rng = SystemRandomNumberGenerator()
    private let randomFilter = CIFilter.randomGenerator()
    
    private let mixer = YIQMixerFilter()
    
    init(intensity: Float, anisotropy: Float, bandwidthScale: Float) {
        self.intensity = intensity
        self.anisotropy = anisotropy
        self.bandwidthScale = bandwidthScale
        super.init()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    private static let kernel = loadKernel()
    private static func loadKernel() -> CIColorKernel {
        let url = Bundle.main.url(forResource: "default", withExtension: "metallib")!
        let data = try! Data(contentsOf: url)
        return try! CIColorKernel(functionName: "Snow", fromMetalLibraryData: data)
    }
    
    override var outputImage: CIImage? {
        guard let inputImage else { return nil }
        guard let randomImage = self.randomFilter.outputImage else { return nil }
        let randomSeed = Float(rng.next())
        let transformedRandomImage = randomImage.transformed(by: CGAffineTransform(translationX: CGFloat(randomSeed), y: CGFloat(randomSeed)))
        let yImage = Self.kernel.apply(
            extent: inputImage.extent,
            arguments: [
                inputImage,
                transformedRandomImage,
                intensity,
                anisotropy,
                bandwidthScale,
                Int(inputImage.extent.width),
            ]
        )
        self.mixer.yiqMix = .y
        self.mixer.mixImage = yImage
        self.mixer.inverseMixImage = inputImage
        return self.mixer.outputImage
    }
}
