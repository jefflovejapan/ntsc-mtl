//
//  ChromaLowpassFilter.swift
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-05-27.
//

import Foundation
import CoreImage

class ChromaLowpassFilter: CIFilter {
    enum Intensity {
        case light
        case full
    }
    let intensity: Intensity
    let iFilter: IIRFilter
    let qFilter: IIRFilter
    private let yiqComposeFilter = YIQComposeFilter()
    var inputImage: CIImage?
    
    init(intensity: Intensity, bandwidthScale: Float, filterType: FilterType) {
        self.intensity = intensity
        switch intensity {
        case .full:
            let iFunction = Self.lowpassFilter(cutoff: 1300000.0, rate: NTSC.rate * bandwidthScale, filterType: filterType)
            iFilter = try! IIRFilter(numerators: iFunction.numerators, denominators: iFunction.denominators, scale: 1, delay: 2)
            let qFunction = Self.lowpassFilter(cutoff: 600000.0, rate: NTSC.rate * bandwidthScale, filterType: filterType)
            qFilter = try! IIRFilter(numerators: qFunction.numerators, denominators: qFunction.denominators, scale: 1, delay: 4)
        case .light:
            let function = Self.lowpassFilter(cutoff: 2600000.0, rate: NTSC.rate * bandwidthScale, filterType: filterType)
            iFilter = try! IIRFilter(numerators: function.numerators, denominators: function.denominators, scale: 1, delay: 1)
            qFilter = try! IIRFilter(numerators: function.numerators, denominators: function.denominators, scale: 1, delay: 1)
        }
        super.init()
    }
    
    required init?(coder: NSCoder) {
        fatalError("Not implemented")
    }
    
    private static func lowpassFilter(cutoff: Float, rate: Float, filterType: FilterType) -> IIRTransferFunction {
        switch filterType {
        case .constantK:
            let lowpass = IIRTransferFunction.lowpassFilter(cutoff: cutoff, rate: rate)
            return lowpass.cascade(n: 3)
        case .butterworth:
            return IIRTransferFunction.butterworth(cutoff: cutoff, rate: rate)
        }
    }
    
    override var outputImage: CIImage? {
        guard let inputImage else { return nil }
        iFilter.inputImage = inputImage
        qFilter.inputImage = inputImage
        yiqComposeFilter.yImage = inputImage
        yiqComposeFilter.iImage = iFilter.outputImage
        yiqComposeFilter.qImage = qFilter.outputImage
        return yiqComposeFilter.outputImage
    }
}
