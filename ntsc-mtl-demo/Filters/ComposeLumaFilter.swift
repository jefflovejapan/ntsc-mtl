//
//  ComposeLumaFilter.swift
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-05-26.
//

import Foundation
import CoreImage

class ComposeLumaFilter: CIFilter {
    var yImage: CIImage?
    var iqImage: CIImage?
    
    private static let kernel = loadKernel()
    private static func loadKernel() -> CIColorKernel {
        let url = Bundle.main.url(forResource: "default", withExtension: "metallib")!
        let data = try! Data(contentsOf: url)
        return try! CIColorKernel(functionName: "ComposeLuma", fromMetalLibraryData: data)
    }
    
    override var outputImage: CIImage? {
        guard let yImage, let iqImage else { return nil }
        return Self.kernel.apply(extent: yImage.extent, arguments: [yImage, iqImage])
    }
}
