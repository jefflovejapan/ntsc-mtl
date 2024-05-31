//
//  MetalConversionTests.swift
//  ntsc-mtl-demoTests
//
//  Created by Jeffrey Blagdon on 2024-05-24.
//

import XCTest
import Metal
@testable import ntsc_mtl_demo
import CoreImage.CIFilterBuiltins

// Create a 1x1 pixel CIImage with a specific color
private func createTestImage(color: CIColor) -> CIImage {
    let img = CIImage(color: color).cropped(to: CGRect(origin: .zero, size: CGSize(width: 100, height: 100)))
    return img
}

private enum Error: Swift.Error {
    case noSamplerOutput
}

private func color(from input: CIImage) throws -> CIColor {
    let context = CIContext()
    let sampler = CIFilter.areaAverage()
    sampler.setValue(input, forKey: kCIInputImageKey)
    guard let output = sampler.outputImage else {
        throw Error.noSamplerOutput
    }
    let outputImage = try XCTUnwrap(context.createCGImage(input, from: input.extent))
    let data = try XCTUnwrap(outputImage.dataProvider?.data)
    let length = CFDataGetLength(data)
    var pixelData = [UInt8](repeating: 0, count: length)
    CFDataGetBytes(data, CFRange(location: 0, length: length), &pixelData)

    let red = CGFloat(pixelData[0]) / 255.0
    let green = CGFloat(pixelData[1]) / 255.0
    let blue = CGFloat(pixelData[2]) / 255.0
    let alpha = CGFloat(pixelData[3]) / 255.0
    return CIColor(red: red, green: green, blue: blue, alpha: alpha)
}

extension CIColor {
    var channelValues: (CGFloat, CGFloat, CGFloat, CGFloat) {
        (red, green, blue, alpha)
    }
}

final class MetalConversionTests: XCTestCase {
    var filter: NTSCFilter!
    
    override func tearDownWithError() throws {
        filter = nil
    }
        
    func testConverstionToYIQ() throws {
        let inputImage = createTestImage(color: CIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1))
        filter = NTSCFilter(size: inputImage.extent.size, effect: .default)
        let toYIQFilter = filter.filters.toYIQ
        
        toYIQFilter.inputImage = inputImage
        let outputImage = try XCTUnwrap(toYIQFilter.outputImage)
        let outputColor = try color(from: outputImage)
        
        let (y, i, q, a) = (outputColor.red, outputColor.green, outputColor.blue, outputColor.alpha)
        XCTAssertEqual(y, 0.521, accuracy: 0.001)
        XCTAssertEqual(i, 0.0, accuracy: 0.001)
        XCTAssertEqual(q, 0.161, accuracy: 0.001)
        XCTAssertEqual(a, 1.0, accuracy: 0.001)
    }
    
    func testConverstionFromYIQ() throws {
        let inputImage = createTestImage(color: CIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1))
        filter = NTSCFilter(size: inputImage.extent.size, effect: .default)
        let toRGBFilter = filter.filters.toRGB
        
        toRGBFilter.inputImage = inputImage
        let outputImage = try XCTUnwrap(toRGBFilter.outputImage)
        let outputColor = try color(from: outputImage)
        
        let (r, g, b, a) = outputColor.channelValues
        XCTAssertEqual(r, 0.820, accuracy: 0.001)
        XCTAssertEqual(g, 0.0, accuracy: 0.001)
        XCTAssertEqual(b, 0.631, accuracy: 0.001)
        XCTAssertEqual(a, 1.0, accuracy: 0.001)
    }
    
    func testRoundTrip() throws {
        let inputColor = CIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1)
        let inputImage = createTestImage(color: inputColor)
        filter = NTSCFilter(size: inputImage.extent.size, effect: .default)
        let toYIQFilter = filter.filters.toYIQ
        let toRGBFilter = filter.filters.toRGB
        
        toYIQFilter.inputImage = inputImage
        let yiqImage = try XCTUnwrap(toYIQFilter.outputImage)
        toRGBFilter.inputImage = yiqImage
        let rgbImage  = try XCTUnwrap(toRGBFilter.outputImage)
        let outputColor = try color(from: rgbImage)
        let channels = (inputColor.channelValues, outputColor.channelValues)
        let (leftR, rightR) = (channels.0.0, channels.1.0)
        XCTAssertEqual(leftR, rightR, accuracy: 0.01)
        let (leftG, rightG) = (channels.0.1, channels.1.1)
        XCTAssertEqual(leftG, rightG, accuracy: 0.01)
        let (leftB, rightB) = (channels.0.2, channels.1.2)
        XCTAssertEqual(leftB, rightB, accuracy: 0.01)
        let (leftA, rightA) = (channels.0.3, channels.1.3)
        XCTAssertEqual(leftA, rightA, accuracy: 0.01)
    }
    
    func testRoundTripHDR() throws {
        let inputColor = CIColor(red: 1.2, green: 1.2, blue: 1.2, alpha: 1)
        let inputImage = createTestImage(color: inputColor)
        filter = NTSCFilter(size: inputImage.extent.size, effect: .default)
        
        let toYIQFilter = filter.filters.toYIQ
        let toRGBFilter = filter.filters.toRGB
        toYIQFilter.inputImage = inputImage
        let yiqImage = try XCTUnwrap(toYIQFilter.outputImage)
        toRGBFilter.inputImage = yiqImage
        let rgbImage  = try XCTUnwrap(toRGBFilter.outputImage)
        let outputColor = try color(from: rgbImage)
        let channels = (inputColor.channelValues, outputColor.channelValues)
        let (leftR, rightR) = (channels.0.0, channels.1.0)
        XCTAssertEqual(leftR, rightR, accuracy: 0.01)
        let (leftG, rightG) = (channels.0.1, channels.1.1)
        XCTAssertEqual(leftG, rightG, accuracy: 0.01)
        let (leftB, rightB) = (channels.0.2, channels.1.2)
        XCTAssertEqual(leftB, rightB, accuracy: 0.01)
        let (leftA, rightA) = (channels.0.3, channels.1.3)
        XCTAssertEqual(leftA, rightA, accuracy: 0.01)
    }
    
    // Test I'm working on now
    func testLumaNotchSetup() throws {
        let yiqColor = CIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1)
        let yiqImage = createTestImage(color: yiqColor)
        var effect: NTSCEffect = .default
        effect.inputLumaFilter = .notch
        filter = NTSCFilter(size: yiqImage.extent.size, effect: effect)
        filter.filters.lumaNotchBlur.inputImage = yiqImage
        let z = filter.filters.lumaNotchBlur.zTextures
        XCTAssertEqual(z.count, 3)   // Why four for Rust? -- They pad it out to 4 for SIMD
        let zColors: [CIColor] = try z.map { tex in
            let img = try XCTUnwrap(CIImage(mtlTexture: tex))
            return try color(from: img)
        }
        let zReds: [CGFloat] = zColors.map { $0.red }
        XCTAssertEqual(zReds, [0.146446615, 0.146446615, 0])  // This is pretty close -- Rust has 0.146
        let outputImage = try XCTUnwrap(filter.filters.lumaNotchBlur.outputImage)
        let outputColor = try color(from: outputImage)
        XCTAssertEqual(outputColor.red, 0.5)    // Why are we ramping luma up to 0.588? What is Rust doing? -- 
    }
    
    private lazy var roundTripKernel: CIColorKernel = loadRoundTripKernel()
    private func loadRoundTripKernel() -> CIColorKernel {
        let url = Bundle.main.url(forResource: "default", withExtension: "metallib")!
        let data = try! Data(contentsOf: url)
        return try! CIColorKernel(functionName: "RoundTrip", fromMetalLibraryData: data)
    }
    
    func testRoundTrippingCyan() throws {
        let cyan = CIColor(cgColor: UIColor.cyan.cgColor)
        XCTAssertEqual(cyan.red, 0)
        XCTAssertEqual(cyan.green, 1)
        XCTAssertEqual(cyan.blue, 1)
        let rgbImage = createTestImage(color: cyan)
        let effect = NTSCEffect.default
        filter = NTSCFilter(size: rgbImage.extent.size, effect: effect)
        filter.filters.toYIQ.inputImage = rgbImage
        let yiqImage = try XCTUnwrap(filter.filters.toYIQ.outputImage)
        filter.filters.toRGB.inputImage = yiqImage
        let roundTripped = try XCTUnwrap(filter.filters.toRGB.outputImage)
        let roundTrippedColor = try color(from: roundTripped)
        XCTAssertEqual(cyan.red, roundTrippedColor.red, accuracy: 0.01)
        XCTAssertEqual(cyan.green, roundTrippedColor.green, accuracy: 0.01)
        XCTAssertEqual(cyan.blue, roundTrippedColor.blue, accuracy: 0.01)
        XCTAssertEqual(cyan.alpha, roundTrippedColor.alpha, accuracy: 0.01)
    }
    
    func testCoolRoundTripCyan() throws {
        let cyan = CIColor(cgColor: UIColor.cyan.cgColor)
        let rgbImage = createTestImage(color: cyan)
        let roundTripped = try XCTUnwrap(self.roundTripKernel.apply(extent: rgbImage.extent, arguments: [rgbImage]))
        let roundTrippedColor = try color(from: roundTripped)
        XCTAssertEqual(cyan.red, roundTrippedColor.red, accuracy: 0.0001)
        XCTAssertEqual(cyan.green, roundTrippedColor.green, accuracy: 0.0001)
        XCTAssertEqual(cyan.blue, roundTrippedColor.blue, accuracy: 0.0001)
        XCTAssertEqual(cyan.alpha, roundTrippedColor.alpha, accuracy: 0.0001)
    }
    
    func testLumaNotchBlur() throws {
        let inputColor = CIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1)
        let inputImage = createTestImage(color: inputColor)
        filter = NTSCFilter(size: inputImage.extent.size, effect: .default)
        filter.filters.toYIQ.inputImage = inputImage
        let yiqImage = try XCTUnwrap(filter.filters.toYIQ.outputImage)
        
        var lumaNotched = yiqImage
        for _ in 0 ..< 10000 {
            filter.filters.lumaNotchBlur.inputImage = yiqImage
            lumaNotched = try XCTUnwrap(filter.filters.lumaNotchBlur.outputImage)
        }
        
        let yiqColor = try color(from: yiqImage)    // data stored in Y, I, and Q
        let yiqChannels = yiqColor.channelValues
        
        let lumaNotchedColor = try color(from: lumaNotched) // data stored in Y, I, and Q
        let lumaNotchedChannels = lumaNotchedColor.channelValues
        
        XCTAssertEqual(yiqChannels.0, lumaNotchedChannels.0, "Luma shouldn't grow just from running through filter")
    }
    
    func testLumaNotchIIR() throws {
        let inputColor = CIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1)
        let inputImage = createTestImage(color: inputColor)
        let transferFunction = IIRTransferFunction.lumaNotch
        XCTAssertEqual(transferFunction.numerators, [0.70710677, -1.0677015e-07, 0.70710677])
        XCTAssertEqual(transferFunction.denominators, [1.0, -1.0677015e-07, 0.41421354])
        /*
         In Rust we get
         
         nums: 0.70710677, 6.181724e-08, 0.70710677, 0.0
         dens: 1.0, 6.181724e-8, 0.41421354, 0.0
         
         Interesting that that middle term is either very small positive (Rust) or very small negative (Swift) but *shouldn't* make that big of a difference
         */
        let firstNumerator = try XCTUnwrap(transferFunction.numerators.first)
        let filteredImage = try XCTUnwrap(IIRFilter.kernels.filterSample.apply(extent: inputImage.extent, arguments: [inputImage, inputImage, firstNumerator]))
        let filteredImageColor = try color(from: filteredImage)
        let expectedFilteredImageRedChannel = inputColor.channelValues.0 + (CGFloat(firstNumerator) * inputColor.channelValues.0)
        
        XCTAssertEqual(expectedFilteredImageRedChannel, filteredImageColor.channelValues.0, accuracy: 0.01)
        let outputImage = try XCTUnwrap(IIRFilter.kernels.finalImage.apply(extent: inputImage.extent, arguments: [inputImage, filteredImage, IIRFilter.lumaNotch().scale]))
        let outputColor = try color(from: outputImage)
        XCTAssertEqual(inputColor.red, outputColor.red) // Why is red getting ramped up to 0.85?
    }
    
    func testRustLumaNotch() throws {
        let transferFunction = IIRTransferFunction.rustLumaNotch
        XCTAssertEqual(transferFunction.numerators, [0.70710677, -1.0677015e-07, 0.70710677])
        XCTAssertEqual(transferFunction.denominators, [1.0, -1.0677015e-07, 0.41421354])
        let filter = try IIRFilter(numerators: transferFunction.numerators, denominators: transferFunction.denominators, initialCondition: .firstSample, scale: 1, delay: 0)
        let inputColor = CIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1)
        let inputImage = createTestImage(color: inputColor)
        filter.inputImage = inputImage
        
        let z = filter.zTextures
        XCTAssertEqual(z.count, 3)   // Why four for Rust? -- They pad it out to 4 for SIMD
        let zColors: [CIColor] = try z.map { tex in
            let img = try XCTUnwrap(CIImage(mtlTexture: tex))
            return try color(from: img)
        }
        let zReds: [CGFloat] = zColors.map { $0.red }
        XCTAssertEqual(zReds, [0.13333333333333333, 0.13333333333333333, 0.0])  // This is pretty close -- Rust has 0.146
        let outputImage = try XCTUnwrap(filter.outputImage)
        let outputColor = try color(from: outputImage)
        XCTAssertEqual(outputColor.red, 0.5)    // Why are we ramping luma up to 0.588? What is Rust doing? --
    }
}
