//
//  QOnlyFilter.swift
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-05-28.
//

import Foundation
import CoreImage

class QOnlyFilter: CIFilter {
    var inputImage: CIImage?
    
    private static let kernel = loadKernel()
    private static func loadKernel() -> CIColorKernel {
        let url = Bundle.main.url(forResource: "default", withExtension: "metallib")!
        let data = try! Data(contentsOf: url)

        return try! CIColorKernel(functionName: "ChannelMixer", fromMetalLibraryData: data)
    }
    
    override var outputImage: CIImage? {
        guard let inputImage else { return nil }
//        let factors: [Float] = [0, 0, 1, 1]
        let factors = CIVector(x: 0, y: 0, z: 1, w: 1)
        return Self.kernel.apply(extent: inputImage.extent, roiCallback: { $1 }, arguments: [inputImage, factors])
    }
}
