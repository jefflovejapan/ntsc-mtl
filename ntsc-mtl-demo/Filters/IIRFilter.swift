//
//  IIRFilter.swift
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-05-25.
//

import CoreImage
import Metal

class IIRFilter: CIFilter {
    struct Kernels {
        var filterSample: CIColorKernel
        var sideEffect: CIColorKernel
        var finalImage: CIColorKernel
    }
    
    private(set) var previousImages: [MTLTexture] = []
    private static let kernels: Kernels = loadKernels()
    private let numerators: [Float]
    private let denominators: [Float]
    private let device: MTLDevice
    private let ciContext: CIContext
    
    var inputImage: CIImage?
    var scale: Float
    
    enum Error: Swift.Error {
        case noMetalDevice
    }
    
    init(numerators: [Float], denominators: [Float], scale: Float, delay: UInt) throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw Error.noMetalDevice
        }
        self.device = device
        let context = CIContext(mtlDevice: device)
        self.ciContext = context
        let maxLength = max(numerators.count, denominators.count)
        var paddedNumerators: [Float] = Array(repeating: 0, count: maxLength)
        paddedNumerators[0..<numerators.count] = numerators[0...]
        var paddedDenominators: [Float] = Array(repeating: 0, count: maxLength)
        paddedDenominators[0..<denominators.count] = denominators[0...]
        self.numerators = paddedNumerators
        self.denominators = paddedDenominators
        self.scale = scale
        super.init()
    }
    
    private static func textures(size: CGSize, device: MTLDevice) -> AnySequence<MTLTexture> {
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: Int(size.width),
            height: Int(size.height),
            mipmapped: false
        )
        textureDescriptor.usage = [.shaderRead, .shaderWrite, .renderTarget]
        return AnySequence {
            AnyIterator {
                device.makeTexture(descriptor: textureDescriptor)
            }
        }
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
        
        if previousImages.isEmpty {
            previousImages = Array(Self.textures(size: inputImage.extent.size, device: device).prefix(numerators.count))
        }

        guard let firstImage = CIImage(mtlTexture: previousImages[0]) else {
            return nil
        }
        
        guard let num = numerators.first else {
            return nil
        }
        guard let filteredImage = Self.kernels.filterSample.apply(extent: inputImage.extent, arguments: [inputImage, firstImage, num]) else {
            return nil
        }
        for i in numerators.indices {
            let nextIdx = i + 1
            guard nextIdx < numerators.count else {
                break
            }
            guard let previousIPlusOne = CIImage(mtlTexture: previousImages[nextIdx]) else {
                break
            }
            if let img = Self.kernels.sideEffect.apply(
                extent: inputImage.extent,
                arguments: [
                    inputImage,
                    previousIPlusOne,
                    filteredImage,
                    numerators[nextIdx],
                    denominators[nextIdx]
                ]
            ) {
                ciContext.render(img, to: previousImages[i], commandBuffer: nil, bounds: img.extent, colorSpace: ciContext.workingColorSpace ?? CGColorSpaceCreateDeviceRGB())
            } else {
                break
            }
        }
        return Self.kernels.finalImage.apply(extent: inputImage.extent, arguments: [inputImage, filteredImage, scale])
    }
}

extension IIRFilter {
    static func lumaNotch() -> IIRFilter {
        let notchFunction = IIRTransferFunction.lumaNotch
        return try! IIRFilter(
            numerators: notchFunction.numerators,
            denominators: notchFunction.denominators,
            scale: 1.0,
            delay: 0
        )
    }
    
    static func compositePreemphasis(_ compositePreemphasis: Float, bandwidthScale: Float) -> IIRFilter {
        let preemphasisFunction = IIRTransferFunction.compositePreemphasis(bandwidthScale: bandwidthScale)
        return try! IIRFilter(
            numerators: preemphasisFunction.numerators,
            denominators: preemphasisFunction.denominators,
            scale: -compositePreemphasis,
            delay: 0
        )
    }
}
