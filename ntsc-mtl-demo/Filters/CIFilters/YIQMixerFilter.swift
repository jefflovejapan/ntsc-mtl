//
//  YIQMixerFilter.swift
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-05-28.
//

import Foundation
import CoreImage

class YIQMixerFilter: CIFilter {
//    var mixImage: CIImage?
//    var inverseMixImage: CIImage?
//    var yiqMix: YIQChannels = .all
//    
//    private static let kernel = loadKernel()
//    private static func loadKernel() -> CIColorKernel {
//        let url = Bundle.main.url(forResource: "default", withExtension: "metallib")!
//        let data = try! Data(contentsOf: url)
//
//        return try! CIColorKernel(functionName: "YIQMix", fromMetalLibraryData: data)
//    }
//    
//    override var outputImage: CIImage? {
//        guard let mixImage, let inverseMixImage else { return nil }
//        return Self.kernel.apply(extent: mixImage.extent, roiCallback: { $1 }, arguments: [mixImage, inverseMixImage, yiqMix.channelMix])
//    }
}
