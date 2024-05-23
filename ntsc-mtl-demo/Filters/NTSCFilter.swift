//
//  HDRZebraFilter.swift
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-05-23.
//

import CoreImage
import Foundation

class NTSCFilter: CIFilter {
    var inputImage: CIImage?
    var inputTime: Float = 0.0

    static var kernel: CIColorKernel = { () -> CIColorKernel in
        let url = Bundle.main.url(forResource: "default", withExtension: "metallib")!
        let data = try! Data(contentsOf: url)
        return try! CIColorKernel(functionName: "NTSC", fromMetalLibraryData: data)
    }()

    override var outputImage: CIImage? {
        guard let input = inputImage else {
            return nil
        }

        return NTSCFilter.kernel.apply(extent: input.extent, arguments: [input, inputTime])
    }
}
