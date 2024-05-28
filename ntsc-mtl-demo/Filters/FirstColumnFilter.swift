//
//  FirstColumnFilter.swift
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-05-28.
//

import Foundation
import CoreImage

class FirstColumnFilter: CIFilter {
    var inputImage: CIImage?
    var iImage: CIImage?
    var qImage: CIImage?
    
    private static let kernel = loadKernel()
    private static func loadKernel() -> CIKernel {
        let url = Bundle.main.url(forResource: "default", withExtension: "metallib")!
        let data = try! Data(contentsOf: url)

        return try! CIKernel(functionName: "FirstColumn", fromMetalLibraryData: data)
    }
    
    override var outputImage: CIImage? {
        guard let inputImage else { return nil }
        return Self.kernel.apply(extent: inputImage.extent, roiCallback: { $1 }, arguments: [inputImage])
    }
}

