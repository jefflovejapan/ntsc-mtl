//
//  HDRZebraFilter.swift
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-05-23.
//

import CoreImage
import Foundation
import CoreImage.CIFilterBuiltins
import SimplexNoiseFilter

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
        let chromaLowpassLight: ChromaLowpassFilter
        let chromaLowpassFull: ChromaLowpassFilter
        let chromaIntoLuma: ChromaIntoLumaFilter
        let compositePreemphasis: IIRFilter
        let compositeNoise: CompositeNoiseFilter
        let toRGB: ToRGBFilter
        
        init(
            toYIQ: ToYIQFilter,
            composeLuma: ComposeLumaFilter,
            lumaBoxBlur: CIFilter,
            lumaNotchBlur: IIRFilter,
            chromaLowpassLight: ChromaLowpassFilter,
            chromaLowpassFull: ChromaLowpassFilter,
            chromaIntoLuma: ChromaIntoLumaFilter,
            compositePreemphasis: IIRFilter,
            compositeNoise: CompositeNoiseFilter,
            toRGB: ToRGBFilter
        ) {
            self.toYIQ = toYIQ
            self.composeLuma = composeLuma
            self.lumaBoxBlur = lumaBoxBlur
            self.lumaNotchBlur = lumaNotchBlur
            self.chromaLowpassLight = chromaLowpassLight
            self.chromaLowpassFull = chromaLowpassFull
            self.chromaIntoLuma = chromaIntoLuma
            self.compositePreemphasis = compositePreemphasis
            self.compositeNoise = compositeNoise
            self.toRGB = toRGB
        }
    }
    
    private func newFilters(size: CGSize) -> Filters {
        return Filters(
            toYIQ: ToYIQFilter(),
            composeLuma: ComposeLumaFilter(),
            lumaBoxBlur: newBoxBlurFilter(),
            lumaNotchBlur: IIRFilter.lumaNotch(),
            chromaLowpassLight: ChromaLowpassFilter(
                intensity: .light,
                bandwidthScale: effect.bandwidthScale,
                filterType: effect.filterType
            ),
            chromaLowpassFull: ChromaLowpassFilter(
                intensity: .full,
                bandwidthScale: effect.bandwidthScale,
                filterType: effect.filterType
            ),
            chromaIntoLuma: ChromaIntoLumaFilter(),
            // TODO: Is this going to break when compositePreemphasis and bandwidthScale dynamically change?
            compositePreemphasis: IIRFilter.compositePreemphasis(
                effect.compositePreemphasis,
                bandwidthScale: effect.bandwidthScale
            ), 
            compositeNoise: CompositeNoiseFilter(noise: effect.compositeNoise),
            toRGB: ToRGBFilter()
        )
    }
    
    private func newBoxBlurFilter() -> CIFilter {
        let boxBlur = CIFilter.boxBlur()
        boxBlur.radius = 4
        return boxBlur
    }
    
    // Step 0
    private func toYIQ(inputImage: CIImage?) -> CIImage? {
        guard let inputImage else { return nil }
        self.filters.toYIQ.inputImage = inputImage
        return self.filters.toYIQ.outputImage
    }
    
    // Step 1
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
    
    // Step2
    private func chromaLowpass(inputImage: CIImage?) -> CIImage? {
        guard let inputImage else { return nil }
        switch effect.chromaLowpassIn {
        case .none:
            return inputImage
        case .light:
            filters.chromaLowpassLight.inputImage = inputImage
            return filters.chromaLowpassLight.outputImage
        case .full:
            filters.chromaLowpassFull.inputImage = inputImage
            return filters.chromaLowpassFull.outputImage
        }
    }
    
    // Step3
    private func chromaIntoLuma(inputImage: CIImage?) -> CIImage? {
        guard let inputImage else { return nil }
        self.filters.chromaIntoLuma.inputImage = inputImage
        return self.filters.chromaIntoLuma.outputImage
    }
    
    // Step4
    private func compositePreemphasis(inputImage: CIImage?) -> CIImage? {
        guard let inputImage else { return nil }
        self.filters.compositePreemphasis.inputImage = inputImage
        return self.filters.compositePreemphasis.outputImage
    }
    
    // Step5
    private func compositeNoise(inputImage: CIImage?) -> CIImage? {
        guard let inputImage else { return nil }
        self.filters.compositeNoise.inputImage = inputImage
        return self.filters.compositeNoise.outputImage
    }
    
    // StepFinal
    private func toRGB(inputImage: CIImage?) -> CIImage? {
        guard let inputImage else { return nil }
        self.filters.toRGB.inputImage = inputImage
        return self.filters.toRGB.outputImage
    }
    
    override var outputImage: CIImage? {
//         step0
        let yiq = toYIQ(inputImage: inputImage)
        // step1
        let lumaed = inputLuma(inputImage: yiq)
        // step2
        // TODO: looks super grayscale, check math
//        let chromaLowpassed = chromaLowpass(inputImage: lumaed)
        // step3
        // TODO: introduces flickering when combined with compositeNoise
//        let chromaedIntoLuma = chromaIntoLuma(inputImage: lumaed)
        // step4
        let composited = compositePreemphasis(inputImage: lumaed)
        // step5
        let compositeNoised = compositeNoise(inputImage: composited)
        // stepFinal
        let rgb = toRGB(inputImage: compositeNoised)
        return rgb
    }
}
