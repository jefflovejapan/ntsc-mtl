//
//  CompositeNoiseFilter.swift
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-05-27.
//

import Foundation
import CoreImage
import SimplexNoiseFilter

// TODO: More faithful implementation of Rust code
class CompositeNoiseFilter: CIFilter {
    private let simplexNoise = SimplexNoiseGenerator()
    private let multiplyLuma = MultiplyLumaFilter()
    
    var inputImage: CIImage?
    var noise: FBMNoiseSettings?
    private var rng = SystemRandomNumberGenerator()
    
    init(noise: FBMNoiseSettings?) {
        self.noise = noise
        super.init()
//        self.simplexNoise.zoom = 1
    }
    
    required init?(coder: NSCoder) {
        fatalError("Not implemented")
    }
     
    private let lumaComposeFilter = ComposeLumaFilter()
    
    override var outputImage: CIImage? {
        let nextX: UInt8 = rng.next(upperBound: 100)
        let nextY: UInt8 = rng.next(upperBound: 100)
        simplexNoise.offsetX = Float(nextX)
        simplexNoise.offsetY = Float(nextY)
        
        guard let inputImage else {
            return nil
        }
        
        guard let noise = simplexNoise.outputImage else { return nil }
        multiplyLuma.intensity = self.noise?.intensity ?? MultiplyLumaFilter.defaultIntensity
        multiplyLuma.mainImage = inputImage
        multiplyLuma.otherImage = noise
        return multiplyLuma.outputImage
    }
}
