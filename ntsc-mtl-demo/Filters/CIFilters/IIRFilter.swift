//
//  IIRFilter.swift
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-05-25.
//

import CoreImage
import Metal

/*
 I don't need to apply factors every step of the way -- that only needs to happen ****AT THE END***
 */

class IIRFilter: CIFilter {
    struct Kernels {
        var initialCondition: CIColorKernel
        var multiply: CIColorKernel
        var filterSample: CIColorKernel
        var sideEffect: CIColorKernel
        var finalImage: CIColorKernel
    }
    
    enum InitialCondition {
        case zero
        case firstSample
        case constant(CIColor)
    }
    
    private(set) var zTextures: [MTLTexture] = []
    static let kernels: Kernels = loadKernels()
    var channelMix: YIQChannels = .all
    private let channelMixer = YIQMixerFilter()
    private let numerators: [Float]
    private let denominators: [Float]
    private let device: MTLDevice
    private let ciContext: CIContext
    private let initialCondition: InitialCondition
    var inputImage: CIImage? {
        didSet {
            if let inputImage, zTextures.isEmpty {
                try! setupInitialCondition(inputImage: inputImage)
            }
        }
    }
    var scale: Float
    
    enum Error: Swift.Error {
        case noMetalDevice
        case noNonZeroDenominators
        case couldntFillTextures
    }
    
    private func setupInitialCondition(inputImage: CIImage) throws {
        let images = Array(Self.textures(size: inputImage.extent.size, device: device).prefix(numerators.count))
        try fillTextures(
            firstImage: inputImage,
            initialCondition: initialCondition,
            numerators: numerators,
            denominators: denominators,
            textures: images
        )
        self.zTextures = images
    }
    
    init(numerators: [Float], denominators: [Float], initialCondition: InitialCondition, scale: Float, delay: UInt) throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw Error.noMetalDevice
        }
        self.device = device
        let context = CIContext(mtlDevice: device)
        self.ciContext = context
        self.initialCondition = initialCondition
        self.numerators = numerators
        self.denominators = denominators
        self.scale = scale
        super.init()
    }
    
    private static func textures(size: CGSize, device: MTLDevice) -> AnySequence<MTLTexture> {
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba16Float,
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
            initialCondition: try! CIColorKernel(functionName: "IIRInitialCondition", fromMetalLibraryData: data),
            multiply: try! CIColorKernel(functionName: "Multiply", fromMetalLibraryData: data),
            filterSample: try! CIColorKernel(functionName: "IIRFilterSample", fromMetalLibraryData: data),
            sideEffect: try! CIColorKernel(functionName: "IIRSideEffect", fromMetalLibraryData: data),
            finalImage: try! CIColorKernel(functionName: "IIRFinalImage", fromMetalLibraryData: data)
        )
    }
    
    private func fillTextures(firstImage: CIImage, initialCondition: InitialCondition, numerators: [Float], denominators: [Float], textures: [MTLTexture]) throws {
        let image: CIImage
        switch initialCondition {
        case .firstSample:
            image = firstImage
        case let .constant(color):
            image = CIImage(color: color).cropped(to: firstImage.extent)
        case .zero:
            image = CIImage(color: .black).cropped(to: firstImage.extent)
            for texture in textures {
                render(image: image, toTexture: texture)
            }
            return
        }
        
        guard let firstNonZeroCoeff = denominators.first(where: { !$0.isZero }) else {
            throw Error.noNonZeroDenominators
        }
        
        let normalizedNumerators = numerators.map { num in
            num / firstNonZeroCoeff
        }
        let normalizedDenominators = denominators.map { den in
            den / firstNonZeroCoeff
        }
        
        var bSum: Float = 0
        for i in 1 ..< numerators.count {
            let num = normalizedNumerators[i]
            let den = normalizedDenominators[i]
            bSum += num - (den * normalizedNumerators[0])
        }
        let z0Fill = bSum / normalizedDenominators.reduce(0, +)
        let z0FillColor = CIColor(
            red: CGFloat(z0Fill),
            green: CGFloat(z0Fill), 
            blue: CGFloat(z0Fill),
            alpha: 1
        )
        
        let initialZ0Image = CIImage(color: z0FillColor).cropped(to: image.extent)
        render(image: initialZ0Image, toTexture: textures[0])
        
        var aSum: Float = 1
        var cSum: Float = 0
        for i in 1 ..< numerators.count {
            let num = normalizedNumerators[i]
            let den = normalizedDenominators[i]
            aSum += den
            cSum += (num - (den * normalizedNumerators[0]))
            let zImage = Self.kernels.initialCondition.apply(
                extent: image.extent,
                arguments: [image, initialZ0Image, aSum, cSum])!
            render(image: zImage, toTexture: textures[i])
        }
        let finalZ0Image = Self.kernels.multiply.apply(extent: image.extent, arguments: [image, initialZ0Image])!
        render(image: finalZ0Image, toTexture: textures[0])
    }
    
    private func render(image: CIImage, toTexture texture: any MTLTexture) {
        ciContext.render(image, to: texture, commandBuffer: nil, bounds: image.extent, colorSpace: ciContext.workingColorSpace ?? CGColorSpaceCreateDeviceRGB())
    }
        
    override var outputImage: CIImage? {
        return nil
//        guard let inputImage else {
//            return nil
//        }
//        
//        if zTextures.isEmpty {
//            let images = Array(Self.textures(size: inputImage.extent.size, device: device).prefix(numerators.count))
//            do {
//                try fillTextures(
//                    firstImage: inputImage,
//                    initialCondition: initialCondition,
//                    numerators: numerators,
//                    denominators: denominators,
//                    textures: images
//                )
//                self.zTextures = images
//            } catch {
//                print("Couldn't set up IIR initial state: \(error)")
//                return nil
//            }
//        }
//
//        guard let tex0 = CIImage(mtlTexture: zTextures[0]) else {
//            return nil
//        }
//        
//        guard let num = numerators.first else {
//            return nil
//        }
//        guard let filteredImage = Self.kernels.filterSample.apply(extent: inputImage.extent, arguments: [inputImage, tex0, num]) else {
//            return nil
//        }
//        for i in numerators.indices {
//            let nextIdx = i + 1
//            guard nextIdx < numerators.count else {
//                break
//            }
//            guard let sideEffectIPlus1 = CIImage(mtlTexture: zTextures[nextIdx]) else {
//                break
//            }
//            if let sideEffected = Self.kernels.sideEffect.apply(
//                extent: inputImage.extent,
//                arguments: [
//                    inputImage,
//                    sideEffectIPlus1,
//                    filteredImage,
//                    numerators[nextIdx],
//                    denominators[nextIdx]
//                ]
//            ) {
//                render(image: sideEffected, toTexture: zTextures[i])
//            } else {
//                break
//            }
//        }
//        let finalImage = Self.kernels.finalImage.apply(extent: inputImage.extent, arguments: [inputImage, filteredImage, scale])
//        channelMixer.mixImage = finalImage
//        channelMixer.yiqMix = channelMix
//        channelMixer.inverseMixImage = inputImage
//        return channelMixer.outputImage
    }
}

extension IIRFilter {
//    static func lumaNotch() -> IIRFilter {
//        let notchFunction = IIRTransferFunction.lumaNotch
//        let filter = try! IIRFilter(
//            numerators: notchFunction.numerators,
//            denominators: notchFunction.denominators, 
//            initialCondition: .firstSample,
//            scale: 1.0,
//            delay: 0
//        )
//        filter.channelMix = .y
//        return filter
//    }
//    
//    static func compositePreemphasis(_ compositePreemphasis: Float, bandwidthScale: Float) -> IIRFilter {
//        let preemphasisFunction = IIRTransferFunction.compositePreemphasis(bandwidthScale: bandwidthScale)
//        let filter = try! IIRFilter(
//            numerators: preemphasisFunction.numerators,
//            denominators: preemphasisFunction.denominators, 
//            initialCondition: .zero,
//            scale: -compositePreemphasis,
//            delay: 0
//        )
//        filter.channelMix = .y
//        return filter
//    }
}
