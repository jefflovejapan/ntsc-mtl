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
    
    private(set) var previousImages: [MTLTexture]
    private static let kernels: Kernels = loadKernels()
    private let numerators: [Float]
    private let denominators: [Float]
    private let device: MTLDevice
    private let ciContext: CIContext
    private var hasInitializedTextures = false
    
    var inputImage: CIImage?
    var scale: Float
    
    enum Error: Swift.Error {
        case noMetalDevice
    }
    
    init(numerators: [Float], denominators: [Float], scale: Float, size: CGSize) throws {
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
        self.previousImages = Array(Self.textures(size: size, device: device).prefix(maxLength))
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
        if !hasInitializedTextures {
            for texture in previousImages {
                ciContext.render(inputImage, to: texture, commandBuffer: nil, bounds: inputImage.extent, colorSpace: self.ciContext.workingColorSpace ?? CGColorSpaceCreateDeviceRGB())
            }
            hasInitializedTextures = true
        }

        let firstImage = CIImage(mtlTexture: previousImages[0]) ?? inputImage
        
        guard let num = numerators.first else {
            return nil
        }
        guard let filteredImage = Self.kernels.filterSample.apply(extent: inputImage.extent, arguments: [inputImage, firstImage, num]) else {
            return nil
        }
        for i in 0..<numerators.count - 1 {
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
    static func lumaNotch(size: CGSize) -> IIRFilter {
        let notchFunction = IIRTransferFunction.lumaNotch
        return try! IIRFilter(
            numerators: notchFunction.numerators,
            denominators: notchFunction.denominators,
            scale: 1.0,
            size: size
        )
    }
}
