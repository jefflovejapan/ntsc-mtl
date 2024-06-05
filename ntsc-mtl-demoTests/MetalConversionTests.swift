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

// Create a 100x100 pixel CIImage with a specific color
private func createTestImage(color: CIColor, size: CGSize = CGSize(width: 100, height: 100)) -> CIImage {
    let img = CIImage(color: color).cropped(to: CGRect(origin: .zero, size: size))
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
    var bitmap = [UInt8](repeating: 0, count: 4)

    // Render the output image to the 1x1 bitmap
    context.render(output, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())

    // Extract the color components
    let red = CGFloat(bitmap[0]) / 255.0
    let green = CGFloat(bitmap[1]) / 255.0
    let blue = CGFloat(bitmap[2]) / 255.0
    let alpha = CGFloat(bitmap[3]) / 255.0
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
    
    func testRoundTrip() throws {
        let inputColor = CIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1)
        let inputImage = createTestImage(color: inputColor)
        let outputImage = try XCTUnwrap(roundTripKernel.apply(extent: inputImage.extent, arguments: [inputImage]))
        
        let outputColor = try color(from: outputImage)
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
        let rgbImage = try XCTUnwrap(self.roundTripKernel.apply(extent: inputImage.extent, arguments: [inputImage]))
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
        let rgbColor = CIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1)
        let inputImage = createTestImage(color: rgbColor)
        var effect: NTSCEffect = .default
        effect.inputLumaFilter = .notch
        filter = NTSCFilter(size: inputImage.extent.size, effect: effect)
        filter.filters.lumaNotchBlur.inputImage = inputImage
        _ = try XCTUnwrap(filter.filters.lumaNotchBlur.outputImage) // Just performing the side effects
        let z = filter.filters.lumaNotchBlur.zTextures
        XCTAssertEqual(z.count, 3)   // Why four for Rust? -- They pad it out to 4 for SIMD
        let zColors: [CIColor] = try z.map { tex in
            let img = try XCTUnwrap(CIImage(mtlTexture: tex))
            return try color(from: img)
        }
        let zYIQs: [SIMD4<Float>] = zColors.map(toYIQ)
        let zYs = zYIQs.map(\.x)    // Since x in the vector represents the y channel data in YIQ color space
        XCTAssertEqual(zYs, [0.14720437, 0.3513723, 0.0])  // This is pretty close -- Rust has 0.146
        let outputImage = try XCTUnwrap(filter.filters.lumaNotchBlur.outputImage)
        let outputColor = try color(from: outputImage)
        XCTAssertEqual(outputColor.red, rgbColor.red, accuracy: 0.03)
        XCTAssertEqual(outputColor.green, rgbColor.green, accuracy: 0.03)
        XCTAssertEqual(outputColor.blue, rgbColor.blue, accuracy: 0.03)
        XCTAssertEqual(outputColor.alpha, rgbColor.alpha, accuracy: 0.03)
    }
    
    private func toYIQ(color: CIColor) -> SIMD4<Float> {
        ntsc_mtl_demo.toYIQ(
            rgba: SIMD4<Float>(
                x: Float(color.red),
                y: Float(color.green),
                z: Float(color.blue),
                w: Float(color.alpha)
            )
        )
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
        let roundTripped = try XCTUnwrap(self.roundTripKernel.apply(extent: rgbImage.extent, arguments: [rgbImage]))
        let roundTrippedColor = try color(from: roundTripped)
        XCTAssertEqual(cyan.red, roundTrippedColor.red, accuracy: 0.01)
        XCTAssertEqual(cyan.green, roundTrippedColor.green, accuracy: 0.01)
        XCTAssertEqual(cyan.blue, roundTrippedColor.blue, accuracy: 0.01)
        XCTAssertEqual(cyan.alpha, roundTrippedColor.alpha, accuracy: 0.01)
    }
    
    func testLumaNotchBlur() throws {
        let inputColor = CIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1)
        let inputImage = createTestImage(color: inputColor)
        filter = NTSCFilter(size: inputImage.extent.size, effect: .default)
        
        var lumaNotched = inputImage
        for _ in 0 ..< 100 {
            filter.filters.lumaNotchBlur.inputImage = inputImage
            lumaNotched = try XCTUnwrap(filter.filters.lumaNotchBlur.outputImage)
        }
        
        let lumaNotchedColor = try color(from: lumaNotched)
        
        XCTAssertEqual(inputColor.red, lumaNotchedColor.red, accuracy: 0.01)
        XCTAssertEqual(inputColor.green, lumaNotchedColor.green, accuracy: 0.01)
        XCTAssertEqual(inputColor.blue, lumaNotchedColor.blue, accuracy: 0.01)
        XCTAssertEqual(inputColor.alpha, lumaNotchedColor.alpha, accuracy: 0.01)
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
        
        // Expected filtered image red channel value is 0.85 based on the filterSample kernel
        
        XCTAssertEqual(expectedFilteredImageRedChannel, filteredImageColor.channelValues.0, accuracy: 0.01)
        let outputImage = try XCTUnwrap(IIRFilter.kernels.finalImage.apply(extent: inputImage.extent, arguments: [inputImage, filteredImage, IIRFilter.lumaNotch().scale]))
        let outputColor = try color(from: outputImage)
        XCTAssertEqual(expectedFilteredImageRedChannel, outputColor.red, accuracy: 0.01) // Why is red getting ramped up to 0.85? -- because it's a linear comination of filterSample, which is 0.85 and scale is 1 for lumaNotch
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
        XCTAssertEqual(zReds, [0.14901960784313725, 0.14901960784313725, 0.0])  // This is pretty close -- Rust has 0.146
        let outputImage = try XCTUnwrap(filter.outputImage)
        let outputColor = try color(from: outputImage)
        XCTAssertEqual(outputColor.red, 0.6, accuracy: 0.01)    // Why are we ramping luma up to 0.6? What is Rust doing?
    }
    
    func testChromaLowpassFullMediumGrey() throws {
        let inputColor = CIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1)
        let inputImage = createTestImage(color: inputColor, size: CGSize(width: 1, height: 1))
        var effect = NTSCEffect.default
        filter = NTSCFilter(size: inputImage.extent.size, effect: effect)
        filter.filters.chromaLowpassFull.inputImage = inputImage
        let outputImage = try XCTUnwrap(filter.filters.chromaLowpassFull.outputImage)
        let outputColor = try color(from: outputImage)
        XCTAssertEqual(inputColor.red, outputColor.red, accuracy: 0.01)
        XCTAssertEqual(inputColor.green, outputColor.green, accuracy: 0.01)
        XCTAssertEqual(inputColor.blue, outputColor.blue, accuracy: 0.01)
        XCTAssertEqual(inputColor.alpha, outputColor.alpha, accuracy: 0.01)
    }
    
    private static func colorFromRGB(_ red: Int, _ green: Int, _ blue: Int) -> CIColor {
        let floatRed = CGFloat(red) / 255
        let floatGreen = CGFloat(green) / 255
        let floatBlue = CGFloat(blue) / 255
        return CIColor(red: floatRed, green: floatGreen, blue: floatBlue, alpha: 1)
    }
    
    func assertEqual(got: CIColor, want: CIColor, line: UInt = #line) {
        XCTAssertEqual(got.red, want.red, accuracy: 0.01, "Wanted \(want.red), got \(got.red) for red", line: line)
        XCTAssertEqual(got.green, want.green, accuracy: 0.01, "Wanted \(want.green), got \(got.green) for green", line: line)
        XCTAssertEqual(got.blue, want.blue, accuracy: 0.01, "Wanted \(want.blue), got \(got.blue) for blue", line: line)
    }
    
    func testChromaLowpassBrightGreen() throws {
        let inputColor = Self.colorFromRGB(20, 230, 20)
        let inputImage = createTestImage(color: inputColor, size: CGSize(width: 1, height: 1))
        var effect = NTSCEffect.default
        effect.filterType = .butterworth
        filter = NTSCFilter(size: inputImage.extent.size, effect: effect)
        filter.filters.chromaLowpassFull.inputImage = inputImage
        let outputImage = try XCTUnwrap(filter.filters.chromaLowpassFull.outputImage)
        let got = try color(from: outputImage)
        let want = Self.colorFromRGB(89, 178, 102)
        assertEqual(got: got, want: want)
    }
    
    func testChromaLowpassTransferFunctionHighI() throws {
        let effect = NTSCEffect.default
        let fullIFunction = ChromaLowpassFilter.lowpassFilter(cutoff: 1_300_000, rate: NTSC.rate * effect.bandwidthScale, filterType: .butterworth)
        let rustNums: [Float] = [0.0572976321, 0.11459526, 0.0572976321]
        let ourNums = fullIFunction.numerators
        for (idx, (got, want)) in zip(ourNums, rustNums).enumerated() {
            XCTAssertEqual(got, want, accuracy: 0.01, "Got \(got), wanted \(want), at index \(idx)")
        }
        let rustDens: [Float] = [1, -1.218135, 0.447325468]
        let ourDens = fullIFunction.denominators
        for (idx, (got, want)) in zip(ourDens, rustDens).enumerated() {
            XCTAssertEqual(got, want, accuracy: 0.01, "Got \(got), wanted \(want), at index \(idx)")
        }
    }
    
    func testChromaLowpassTransferFunctionHighQ() throws {
        let effect = NTSCEffect.default
        let fullQFunction = ChromaLowpassFilter.lowpassFilter(cutoff: 600_000, rate: NTSC.rate * effect.bandwidthScale, filterType: .butterworth)
        let rustNums: [Float] = [0.0145529797, 0.0291059595, 0.0145529797]
        let ourNums = fullQFunction.numerators
        for (idx, (got, want)) in zip(ourNums, rustNums).enumerated() {
            XCTAssertEqual(got, want, accuracy: 0.01, "Got \(got), wanted \(want), at index \(idx)")
        }
        let rustDens: [Float] = [1, -1.6309284, 0.68914032]
        let ourDens = fullQFunction.denominators
        for (idx, (got, want)) in zip(ourDens, rustDens).enumerated() {
            XCTAssertEqual(got, want, accuracy: 0.01, "Got \(got), wanted \(want), at index \(idx)")
        }
    }
}
