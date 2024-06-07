//
//  BandingTests.swift
//  ntsc-mtl-demoTests
//
//  Created by Jeffrey Blagdon on 2024-06-06.
//

import XCTest
@testable import ntsc_mtl_demo
import Metal
import CoreImage

final class BandingTests: XCTestCase {
    var inputImage: CIImage!
    var device: MTLDevice!
    var library: MTLLibrary!
    var commandQueue: MTLCommandQueue!
    var ciContext: CIContext!
    var filter: NTSCTextureFilter!

    override func setUpWithError() throws {
        let imageURL = try XCTUnwrap(Bundle(for: BandingTests.self).url(forResource: "video-frame", withExtension: "jpg"))
        let imageData = try Data(contentsOf: imageURL)
        self.inputImage = CIImage(data: imageData)
        let effect: NTSCEffect = .default
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        self.device = device
        self.library = try XCTUnwrap(device.makeDefaultLibrary())
        let commandQueue = try XCTUnwrap(device.makeCommandQueue())
        self.commandQueue = commandQueue
        let ciContext = CIContext(mtlCommandQueue: commandQueue)
        self.ciContext = ciContext
        self.filter = try NTSCTextureFilter(effect: effect, device: device, context: ciContext)
    }

    override func tearDownWithError() throws {
        self.filter = nil
        self.ciContext = nil
        self.commandQueue = nil
        self.device = nil
        self.inputImage = nil
    }

    func testApplyingFilter() throws {
        self.filter.inputImage = inputImage
        // Got some banding already
        let outputImage = try XCTUnwrap(self.filter.outputImage)
        XCTAssertEqual(Int(outputImage.extent.height), 100)
    }
    
    func outputImage(for inputImage: CIImage) throws -> CIImage {
        let commandBuffer = try XCTUnwrap(commandQueue.makeCommandBuffer())
        let textureA = try XCTUnwrap(IIRTextureFilter.texture(width: Int(inputImage.extent.width), height: Int(inputImage.extent.height), pixelFormat: .rgba16Float, device: device))
        let textureB = try XCTUnwrap(IIRTextureFilter.texture(from: textureA, device: device))
        
        ciContext.render(inputImage, to: textureA, commandBuffer: commandBuffer, bounds: inputImage.extent, colorSpace: ciContext.workingColorSpace ?? CGColorSpaceCreateDeviceRGB())
        try NTSCTextureFilter.convertToYIQ(textureA, output: textureB, library: library, commandBuffer: commandBuffer, device: device)
        
        let function = IIRTransferFunction.lowpassFilter(cutoff: 1_300_000, rate: NTSC.rate * 1)
        let fullIButterworthFilter = IIRTextureFilter(device: device, library: library, numerators: function.numerators, denominators: function.denominators, initialCondition: .zero, channels: .i, scale: 1, delay: 2)
        try fullIButterworthFilter.run(inputTexture: textureB, outputTexture: textureA, commandBuffer: commandBuffer)
        try NTSCTextureFilter.convertToRGB(textureA, output: textureB, commandBuffer: commandBuffer, library: library, device: device)
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        return try XCTUnwrap(CIImage(mtlTexture: textureB))
    }
    
    func testApplyingChroma() throws {
        let outputImage = try outputImage(for: inputImage)
        XCTAssertEqual(Int(outputImage.extent.width), 100)
    }
    
    func saveCIImageToDisk(_ ciImage: CIImage, filename: String, context: CIContext) throws {
        // Convert CIImage to CGImage
        let cgImage = try XCTUnwrap(context.createCGImage(ciImage, from: ciImage.extent))
        let uiImage = UIImage(cgImage: cgImage)
        let data = try XCTUnwrap(uiImage.pngData())
        let url = try XCTUnwrap(FileManager.default.temporaryDirectory.appendingPathComponent(filename))
        try data.write(to: url)
    }
    
    func testApplyingChromaToPlainWhiteImage() throws {
        let strideSize: CGFloat = 0.1
        let rangeStart: CGFloat = 0
        let rangeEnd: CGFloat = 1
        for r in stride(from: rangeStart, to: rangeEnd, by: strideSize) {
            for g in stride(from: rangeStart, to: rangeEnd, by: strideSize) {
                for b in stride(from: rangeStart, to: rangeEnd, by: strideSize) {
                    let image = createTestImage(color: CIColor(red: r, green: g, blue: b), size: CGSize(width: 1000, height: 1000))
                    let outputImage = try outputImage(for: image)
                    try saveCIImageToDisk(outputImage, filename: "red: \(r) green: \(g), blue: \(b).png", context: ciContext)
                    XCTAssertEqual(Int(outputImage.extent.width), 1000)
                }
            }
        }
    }
}
