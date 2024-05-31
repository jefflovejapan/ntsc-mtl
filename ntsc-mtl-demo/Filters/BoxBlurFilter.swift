//
//  BoxBlurFilter.swift
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-05-31.
//

import Foundation
import CoreImage
import CoreImage.CIFilterBuiltins

class BoxBlurFilter: CIFilter {
    var channels: YIQChannels = .all
    var inputImage: CIImage?
    
    private let mixer = YIQMixerFilter()
    private let boxBlurFilter = BoxBlurFilter.newBoxBlurFilter()
    private static func newBoxBlurFilter() -> CIFilter {
        let filter = CIFilter.boxBlur()
        filter.radius = 100
        return filter
    }
    
    override var outputImage: CIImage? {
        guard let inputImage else {
            return nil
        }
        boxBlurFilter.setValue(inputImage, forKey: kCIInputImageKey)
        guard let blurredImage = boxBlurFilter.outputImage else {
            return nil
        }
        
        mixer.mixImage = blurredImage.cropped(to: inputImage.extent)
        mixer.inverseMixImage = inputImage
        mixer.yiqMix = .y
        return mixer.outputImage
    }
    
}
