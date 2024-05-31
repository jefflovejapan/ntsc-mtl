//
//  ChannelMixerFilter.swift
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-05-28.
//

import Foundation
import CoreImage

/*
 Let's say that we want to take two images, A and B
 
 We want to mix them according to the yiqChannelMix
 
 Let's say A is blurred and B is not
 */

class YIQMixerFilter: CIFilter {
    var mixImage: CIImage?
    var inverseMixImage: CIImage?
    var yiqMix: YIQChannels = .all
    
    private static let kernel = loadKernel()
    private static func loadKernel() -> CIColorKernel {
        let url = Bundle.main.url(forResource: "default", withExtension: "metallib")!
        let data = try! Data(contentsOf: url)

        return try! CIColorKernel(functionName: "ChannelMixer", fromMetalLibraryData: data)
    }
    
    override var outputImage: CIImage? {
        guard let mixImage, let inverseMixImage else { return nil }
        return Self.kernel.apply(extent: mixImage.extent, roiCallback: { $1 }, arguments: [mixImage, inverseMixImage, yiqMix.channelMix])
    }
}
