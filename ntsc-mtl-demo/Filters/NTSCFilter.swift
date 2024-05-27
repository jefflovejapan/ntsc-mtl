//
//  HDRZebraFilter.swift
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-05-23.
//

import CoreImage
import Foundation
import CoreImage.CIFilterBuiltins

class NTSCFilter: CIFilter {
    var inputImage: CIImage?
    var effect: NTSCEffect = .default
    let size: CGSize
    private(set) lazy var filters = newFilters(size: size)
    
    init(size: CGSize) {
        self.size = size
        super.init()
    }
    
    required init?(coder: NSCoder) {
        fatalError("Not implemented")
    }
    
    class Filters {
        let toYIQ: ToYIQFilter
        let composeLuma: ComposeLumaFilter
        let lumaBoxBlur: CIFilter
        let lumaNotchBlur: IIRFilter
        let chromaIntoLuma: ChromaIntoLumaFilter
        let compositePreemphasis: IIRFilter
        let toRGB: ToRGBFilter
        
        init(
            toYIQ: ToYIQFilter,
            composeLuma: ComposeLumaFilter,
            lumaBoxBlur: CIFilter,
            lumaNotchBlur: IIRFilter,
            chromaIntoLuma: ChromaIntoLumaFilter,
            compositePreemphasis: IIRFilter,
            toRGB: ToRGBFilter
        ) {
            self.toYIQ = toYIQ
            self.composeLuma = composeLuma
            self.lumaBoxBlur = lumaBoxBlur
            self.lumaNotchBlur = lumaNotchBlur
            self.chromaIntoLuma = chromaIntoLuma
            self.compositePreemphasis = compositePreemphasis
            self.toRGB = toRGB
        }
    }
    
    private func newFilters(size: CGSize) -> Filters {
        return Filters(
            toYIQ: ToYIQFilter(),
            composeLuma: ComposeLumaFilter(),
            lumaBoxBlur: newBoxBlurFilter(),
            lumaNotchBlur: IIRFilter.lumaNotch(),
            chromaIntoLuma: ChromaIntoLumaFilter(), 
            compositePreemphasis: IIRFilter.compositePreemphasis(effect.compositePreemphasis, bandwidthScale: effect.bandwidthScale), // TODO: Is this going to break when compositePreemphasis and bandwidthScale dynamically change?
            toRGB: ToRGBFilter()
        )
    }
    
    private func newBoxBlurFilter() -> CIFilter {
        let boxBlur = CIFilter.boxBlur()
        boxBlur.radius = 4
        return boxBlur
    }
    
    private func toYIQ(inputImage: CIImage?) -> CIImage? {
        guard let inputImage else { return nil }
        self.filters.toYIQ.inputImage = inputImage
        return self.filters.toYIQ.outputImage
    }
    
    private func inputLuma(inputImage: CIImage?) -> CIImage? {
        guard let inputImage else { return nil }
        let lumaed: CIImage?
        switch effect.inputLumaFilter {
        case .box:
            self.filters.lumaBoxBlur.setValue(inputImage, forKey: kCIInputImageKey)
            lumaed = self.filters.lumaBoxBlur.outputImage
        case .notch:
            self.filters.lumaNotchBlur.inputImage = inputImage
            lumaed = self.filters.lumaNotchBlur.outputImage
        case .none:
            lumaed = inputImage
        }
        guard let lumaed else {
            return nil
        }
        
        self.filters.composeLuma.yImage = lumaed
        self.filters.composeLuma.iqImage = inputImage
        return self.filters.composeLuma.outputImage
    }
    
    private func chromaIntoLuma(inputImage: CIImage?) -> CIImage? {
        guard let inputImage else { return nil }
        self.filters.chromaIntoLuma.inputImage = inputImage
        return self.filters.chromaIntoLuma.outputImage
    }
    
    private func compositePreemphasis(inputImage: CIImage?) -> CIImage? {
        guard let inputImage else { return nil }
        self.filters.compositePreemphasis.inputImage = inputImage
        return self.filters.compositePreemphasis.outputImage
    }
    
    private func toRGB(inputImage: CIImage?) -> CIImage? {
        guard let inputImage else { return nil }
        self.filters.toRGB.inputImage = inputImage
        return self.filters.toRGB.outputImage
    }

    override var outputImage: CIImage? {
        let yiq = toYIQ(inputImage: inputImage)
        let lumaed = inputLuma(inputImage: yiq)
        let composited = compositePreemphasis(inputImage: lumaed)
        let rgb = toRGB(inputImage: lumaed)
        return rgb
    }
}
