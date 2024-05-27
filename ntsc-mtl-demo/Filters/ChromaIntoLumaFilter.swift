//
//  ChromaIntoLumaFilter.swift
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-05-27.
//

import Foundation
import CoreImage

class ChromaIntoLumaFilter: CIFilter {
    var inputImage: CIImage?
    var phaseShift: PhaseShift = NTSCEffect.default.videoScanlinePhaseShift
    var phaseShiftOffset: Int = NTSCEffect.default.videoScanlinePhaseShiftOffset
    
    private var frameNumber: UInt = 0
    private static let kernel = loadKernel()
    
    private static func loadKernel() -> CIColorKernel {
        let url = Bundle.main.url(forResource: "default", withExtension: "metallib")!
        let data = try! Data(contentsOf: url)
        return try! CIColorKernel(functionName: "ChromaIntoLuma", fromMetalLibraryData: data)
    }
    
    override var outputImage: CIImage? {
        guard let inputImage else { return nil }
        defer { frameNumber += 1 }
        return Self.kernel.apply(extent: inputImage.extent, arguments: [inputImage, phaseShift.rawValue, phaseShiftOffset])
    }
}

