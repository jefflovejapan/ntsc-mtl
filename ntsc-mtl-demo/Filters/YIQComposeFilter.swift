//
//  YIQComposeFilter.swift
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-05-27.
//

import Foundation
import CoreImage

class YIQComposeFilter: CIFilter {
    var yImage: CIImage?
    var iImage: CIImage?
    var qImage: CIImage?
    
    private static let kernel = loadKernel()
    private static func loadKernel() -> CIColorKernel {
        let url = Bundle.main.url(forResource: "default", withExtension: "metallib")!
        let data = try! Data(contentsOf: url)
        return try! CIColorKernel(functionName: "YIQCompose", fromMetalLibraryData: data)
    }
    
    override var outputImage: CIImage? {
        guard let yImage, let iImage, let qImage else { return nil }
        return Self.kernel.apply(extent: yImage.extent, arguments: [yImage, iImage, qImage])
    }
}
