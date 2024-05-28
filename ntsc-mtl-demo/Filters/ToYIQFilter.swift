//
//  ToYIQFilter.swift
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-05-26.
//

import Foundation
import CoreImage

class ToYIQFilter: CIFilter {
    var inputImage: CIImage?
    
    private static let kernel = loadKernel()
    private static func loadKernel() -> CIColorKernel {
        let url = Bundle.main.url(forResource: "default", withExtension: "metallib")!
        let data = try! Data(contentsOf: url)
        return try! CIColorKernel(functionName: "ToYIQ", fromMetalLibraryData: data)
    }
    
    override var outputImage: CIImage? {
        guard let inputImage else { return nil }
        return Self.kernel.apply(extent: inputImage.extent, arguments: [inputImage])
    }
}