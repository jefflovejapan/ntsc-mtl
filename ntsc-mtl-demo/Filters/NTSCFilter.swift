//
//  HDRZebraFilter.swift
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-05-23.
//

import CoreImage
import Foundation

class NTSCFilter: CIFilter {
    enum LumaLowpass {
        case box
        case notch
        case none
    }
    
    var inputImage: CIImage?
    var intensity: CGFloat = 0
    var inputTime: Float = 0.0
    var lumaLowpass: LumaLowpass = .box
    static var kernels: Kernels = newKernels()
    struct Kernels {
        var toYIQ: CIColorKernel
        var blue: CIColorKernel
        var lumaBox: CIColorKernel
        var lumaNotch: CIColorKernel
        var toRGB: CIColorKernel
    }
    
    private static func newKernels() -> Kernels {
        let url = Bundle.main.url(forResource: "default", withExtension: "metallib")!
        let data = try! Data(contentsOf: url)
        return Kernels(
            toYIQ: try! CIColorKernel(functionName: "ToYIQ", fromMetalLibraryData: data),
            blue: try! CIColorKernel(functionName: "Blue", fromMetalLibraryData: data),
            lumaBox: try! CIColorKernel(functionName: "LumaBox", fromMetalLibraryData: data),
            lumaNotch: try! CIColorKernel(functionName: "LumaNotch", fromMetalLibraryData: data),
            toRGB: try! CIColorKernel(functionName: "ToRGB", fromMetalLibraryData: data)
        )
    }

    override var outputImage: CIImage? {
        guard let input = inputImage else {
            return nil
        }

        return NTSCFilter.kernels.blue.apply(extent: input.extent, arguments: [input, inputTime, intensity])
    }
}
