//
//  IIRFilter.swift
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-05-25.
//

import CoreImage

class IIRFilter: CIFilter {
    struct Kernels {
        var iir1: CIColorKernel
        var iir2: CIColorKernel
        var iir3: CIColorKernel
    }
    
    private var previousImages: FixedLengthQueue<CIImage>
    private lazy var kernel: CIColorKernel = loadKernel()
    private let numerators: [Float]
    private let denominators: [Float]
    var inputImage: CIImage?
    init(numerators: [Float], denominators: [Float]) {
        let maxLength = max(numerators.count, denominators.count)
        var paddedNumerators: [Float] = Array(repeating: 0, count: maxLength)
        paddedNumerators[0..<numerators.count] = numerators[0...]
        var paddedDenominators: [Float] = Array(repeating: 0, count: maxLength)
        paddedDenominators[0..<denominators.count] = denominators[0...]
        self.numerators = paddedNumerators
        self.denominators = paddedDenominators
        self.previousImages = FixedLengthQueue(capacity: maxLength)
        super.init()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func loadKernel() -> CIColorKernel {
        let url = Bundle.main.url(forResource: "default", withExtension: "metallib")!
        let data = try! Data(contentsOf: url)
        switch numerators.count {
        case 1:
            return try! CIColorKernel(functionName: "IIR1", fromMetalLibraryData: data)
        case 2:
            return try! CIColorKernel(functionName: "IIR2", fromMetalLibraryData: data)
        case 3:
            return try! CIColorKernel(functionName: "IIR3", fromMetalLibraryData: data)
        default:
            fatalError("No kernel available for numerator count of \(numerators.count)")
        }
    }
    
    func paddedOutputImages(count: Int) -> [CIImage] {
        let previousImages = previousImages.elements
        if previousImages.count >= count {
            return Array(previousImages[0..<count])
        }
        guard let imageToRepeat = previousImages.first ?? inputImage else {
            return []
        }
        var images = Array(repeating: imageToRepeat, count: count)
        let sliceStartIndex = count - previousImages.count
        images[sliceStartIndex..<count-1] = previousImages[0...]
        return images
    }
    
    override var outputImage: CIImage? {
        guard let inputImage else { return nil }
        let pastImages = self.paddedOutputImages(count: numerators.count)
        guard let outputImage = kernel.apply(extent: inputImage.extent, arguments: pastImages) else { return nil }
        self.previousImages.push(outputImage)
        return outputImage
    }
}
