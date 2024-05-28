//
//  ChannelMixerFilter.swift
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-05-28.
//

import Foundation
import CoreImage

class ChannelMixerFilter: CIFilter {
    @objc dynamic var inputImage: CIImage?
    var factors: CIVector?
    
    static let yOnlyFactors = CIVector(x: 1, y: 0, z: 0, w: 1)
    static let iOnlyFactors = CIVector(x: 0, y: 1, z: 0, w: 1)
    static let qOnlyFactors = CIVector(x: 0, y: 0, z: 1, w: 1)
    
    private static let kernel = loadKernel()
    private static func loadKernel() -> CIColorKernel {
        let url = Bundle.main.url(forResource: "default", withExtension: "metallib")!
        let data = try! Data(contentsOf: url)

        return try! CIColorKernel(functionName: "ChannelMixer", fromMetalLibraryData: data)
    }
    
    override var outputImage: CIImage? {
        guard let inputImage, let factors else { return nil }
        return Self.kernel.apply(extent: inputImage.extent, roiCallback: { $1 }, arguments: [inputImage, factors])
    }
}
