//
//  IIRFilter.swift
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-05-25.
//

import CoreImage

class IIRFilter: CIFilter {
    struct Kernels {
        var filterSample: CIColorKernel
        var sideEffect: CIColorKernel
        var finalImage: CIColorKernel
    }
    
    private(set) var previousImages: [CIImage?]
    private static let kernels: Kernels = loadKernels()
    private let numerators: [Float]
    private let denominators: [Float]
    static let ctx = CIContext()
    
    var inputImage: CIImage?
    var scale: Float
    init(numerators: [Float], denominators: [Float], scale: Float) {
        let maxLength = max(numerators.count, denominators.count)
        var paddedNumerators: [Float] = Array(repeating: 0, count: maxLength)
        paddedNumerators[0..<numerators.count] = numerators[0...]
        var paddedDenominators: [Float] = Array(repeating: 0, count: maxLength)
        paddedDenominators[0..<denominators.count] = denominators[0...]
        self.numerators = paddedNumerators
        self.denominators = paddedDenominators
        self.previousImages = Array(repeating: nil, count: maxLength)
        self.scale = scale
        super.init()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private static func loadKernels() -> Kernels {
        let url = Bundle.main.url(forResource: "default", withExtension: "metallib")!
        let data = try! Data(contentsOf: url)
        return Kernels(
            filterSample: try! CIColorKernel(functionName: "IIRFilterSample", fromMetalLibraryData: data),
            sideEffect: try! CIColorKernel(functionName: "IIRSideEffect", fromMetalLibraryData: data),
            finalImage: try! CIColorKernel(functionName: "IIRFinalImage", fromMetalLibraryData: data)
        )
    }
    
    override var outputImage: CIImage? {
        guard let inputImage else {
            return nil
        }
        let prevImage: CIImage
        if let maybeFirstImage = previousImages.first, let firstImage = maybeFirstImage {
            prevImage = firstImage
        } else {
            prevImage = inputImage
        }
        guard let num = numerators.first else {
            return nil
        }
        guard let filteredImage = Self.kernels.filterSample.apply(extent: inputImage.extent, arguments: [inputImage, prevImage, num]) else {
            return nil
        }
        for i in 0..<numerators.count {
            let nextIdx = i + 1
            guard nextIdx < numerators.count else { break }
            let imageIPlusOne: CIImage
            if nextIdx < previousImages.count, let prevImg = previousImages[nextIdx] {
                imageIPlusOne = prevImg
            } else if let lastImg = previousImages.compactMap({ $0 }).last {
                imageIPlusOne = lastImg
            } else {
                imageIPlusOne = inputImage
            }
            if let img = Self.kernels.sideEffect.apply(
                extent: inputImage.extent,
                arguments: [
                    inputImage,
                    imageIPlusOne,
                    filteredImage,
                    numerators[nextIdx],
                    denominators[nextIdx]
                ]
            ), let cgImage = Self.ctx.createCGImage(img, from: img.extent) {
                let convertedImage = CIImage(cgImage: cgImage)
                
                previousImages[i] = convertedImage
            }
        }
        return Self.kernels.finalImage.apply(extent: inputImage.extent, arguments: [inputImage, filteredImage, scale])
    }
}

extension IIRFilter {
    static func lumaNotch() -> IIRFilter {
        let notchFunction = IIRTransferFunction.lumaNotch
        return IIRFilter(
            numerators: notchFunction.numerators,
            denominators: notchFunction.denominators,
            scale: 1.0
        )
    }
}
