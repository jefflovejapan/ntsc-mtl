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
    let pixel = [UInt8(color.red * 255), UInt8(color.green * 255), UInt8(color.blue * 255), UInt8(color.alpha * 255)]
    let data = Data(pixel)
    let bitmap = CIImage(bitmapData: data, bytesPerRow: 4, size: CGSize(width: 1, height: 1), format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())
    return bitmap
}

private func color(from input: CIImage) throws -> CIColor {
    let context = CIContext()
    let outputPixel = try XCTUnwrap(context.createCGImage(input, from: input.extent))
    let data = try XCTUnwrap(outputPixel.dataProvider?.data)
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
        filter = NTSCFilter(size: inputImage.extent.size)
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
        filter = NTSCFilter(size: inputImage.extent.size)
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
        filter = NTSCFilter(size: inputImage.extent.size)
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
        filter = NTSCFilter(size: inputImage.extent.size)
        
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
}
