//
//  HDRZebraFilter.swift
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-05-23.
//

import CoreImage
import Foundation

class NTSCFilter: CIFilter {
    var inputImage: CIImage?
    var effect: NTSCEffect = .default
    static var kernels: Kernels = newKernels()
    struct Kernels {
        var toYIQ: CIColorKernel
        var blue: CIColorKernel
        var lumaBox: CIKernel
//        var lumaNotch: CIColorKernel
        var toRGB: CIColorKernel
    }
    
    private static func newKernels() -> Kernels {
        let url = Bundle.main.url(forResource: "default", withExtension: "metallib")!
        let data = try! Data(contentsOf: url)
        return Kernels(
            toYIQ: try! CIColorKernel(functionName: "ToYIQ", fromMetalLibraryData: data),
            blue: try! CIColorKernel(functionName: "Blue", fromMetalLibraryData: data),
            lumaBox: try! CIKernel(functionName: "LumaBox", fromMetalLibraryData: data),
//            lumaNotch: try! CIColorKernel(functionName: "LumaNotch", fromMetalLibraryData: data),
            toRGB: try! CIColorKernel(functionName: "ToRGB", fromMetalLibraryData: data)
        )
    }

    override var outputImage: CIImage? {
        guard let input = inputImage else {
            return nil
        }

        guard let convertedToYIQ = Self.kernels.toYIQ.apply(extent: input.extent, arguments: [input]) else {
            return nil
        }
        let lumaed: CIImage?
        switch effect.inputLumaFilter {
        case .box:
            lumaed = Self.kernels.lumaBox.apply(extent: convertedToYIQ.extent, roiCallback: { _, rect in rect }, arguments: [convertedToYIQ])
        case .notch:
            lumaed = nil
        case .none:
            lumaed = convertedToYIQ
        }
        guard let lumaed else {
            return nil
        }
        
        guard let convertedToRGB = Self.kernels.toRGB.apply(extent: lumaed.extent, arguments: [lumaed]) else {
            return nil
        }
        
        return convertedToRGB
    }
}
