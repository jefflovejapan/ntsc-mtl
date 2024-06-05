//
//  MetalTextureConversionTests.swift
//  ntsc-mtl-demoTests
//
//  Created by Jeffrey Blagdon on 2024-06-04.
//

import XCTest
@testable import ntsc_mtl_demo
import Metal

final class MetalTextureConversionTests: XCTestCase {
    enum Error: Swift.Error {
        case noDevice
    }
    
    private var library: MTLLibrary?
    private var texture: MTLTexture?
    private var device: MTLDevice?
    private var ciContext: CIContext?
    private var commandQueue: MTLCommandQueue?

    override func setUpWithError() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw Error.noDevice
        }
        self.device = device
        self.ciContext = CIContext(mtlDevice: device)
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba32Float, width: 1, height: 1, mipmapped: false)
        self.texture = device.makeTexture(descriptor: textureDescriptor)
        self.commandQueue = try XCTUnwrap(device.makeCommandQueue())
        self.library = try XCTUnwrap(device.makeDefaultLibrary())
    }
    
    override func tearDownWithError() throws {
        self.library = nil
        self.commandQueue = nil
        self.texture = nil
        self.ciContext = nil
        self.device = nil
    }
    
    func testMetalRoundTrip() throws {
        let texture = try XCTUnwrap(texture)
        let input: [Float] = [0.5, 0.5, 0.5, 1]
        var rgba = input
        let region = MTLRegionMake2D(0, 0, 1, 1)
        let bytesPerRow: Int = MemoryLayout<Float>.size * 4 * 1
        texture.replace(region: region, mipmapLevel: 0, withBytes: &rgba, bytesPerRow: bytesPerRow)
        var newValue: [Float] = [0, 0, 0, 0]
        texture.getBytes(&newValue, bytesPerRow: bytesPerRow, from: region, mipmapLevel: 0)
        XCTAssertEqual(rgba, input)
        XCTAssertEqual(newValue, input)
    }
    
    func testYIQConversion() throws {
        let texture = try XCTUnwrap(texture)
        let commandBuffer = try XCTUnwrap(commandQueue?.makeCommandBuffer())
        let device = try XCTUnwrap(device)
        let library = try XCTUnwrap(library)
        let input: [Float] = [0.5, 0.5, 0.5, 1]
        var rgba = input
        let region = MTLRegionMake2D(0, 0, 1, 1)
        let bytesPerRow: Int = MemoryLayout<Float>.size * 4 * 1
        texture.replace(region: region, mipmapLevel: 0, withBytes: &rgba, bytesPerRow: bytesPerRow)
        try NTSCTextureFilter.convertToYIQ(
            texture,
            library: library,
            commandBuffer: commandBuffer,
            device: device
        )
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        // from Rust
        let want: [Float] = [0.5, 0, -1.4901161e-8, 1]
        var got: [Float] = [0, 0, 0, 0]
        texture.getBytes(&got, bytesPerRow: bytesPerRow, from: region, mipmapLevel: 0)
        XCTAssertEqual(want, got)
    }
    
    func testRGBConversion() throws {
        let texture = try XCTUnwrap(texture)
        let commandBuffer = try XCTUnwrap(commandQueue?.makeCommandBuffer())
        let library = try XCTUnwrap(library)
        let device = try XCTUnwrap(device)
        let input: [Float] = [0.5, 0.5, 0.5, 1]
        var yiqa = input
        let region = MTLRegionMake2D(0, 0, 1, 1)
        let bytesPerRow: Int = MemoryLayout<Float>.size * 4 * 1
        texture.replace(region: region, mipmapLevel: 0, withBytes: &yiqa, bytesPerRow: bytesPerRow)
        try NTSCTextureFilter.convertToRGB(
            texture,
            commandBuffer: commandBuffer,
            library: library,
            device: device
        )
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        // from Rust
        let want: [Float] = [1.2875, 0.040499985, 0.7985, 1]
        var got: [Float] = [0, 0, 0, 0]
        texture.getBytes(&got, bytesPerRow: bytesPerRow, from: region, mipmapLevel: 0)
        XCTAssertEqual(want, got)
    }
    
    func testRGBRoundTrip() throws {
        let texture = try XCTUnwrap(texture)
        let library = try XCTUnwrap(library)
        let device = try XCTUnwrap(device)
        let commandBuffer = try XCTUnwrap(commandQueue?.makeCommandBuffer())
        let input: [Float] = [0.5, 0.5, 0.5, 1]
        var rgba = input
        let region = MTLRegionMake2D(0, 0, 1, 1)
        let bytesPerRow: Int = MemoryLayout<Float>.size * 4 * 1
        texture.replace(region: region, mipmapLevel: 0, withBytes: &rgba, bytesPerRow: bytesPerRow)
        try NTSCTextureFilter.convertToYIQ(texture, library: library, commandBuffer: commandBuffer, device: device)
        try NTSCTextureFilter.convertToRGB(texture, commandBuffer: commandBuffer, library: library, device: device)
        // Expecting not to lose any precision when moving back and forth
        let want: [Float] = input
        var got: [Float] = [0, 0, 0, 0]
        texture.getBytes(&got, bytesPerRow: bytesPerRow, from: region, mipmapLevel: 0)
        for idx in input.indices {
            XCTAssertEqual(want[idx], got[idx], accuracy: 0.00001, "Mismatch at index \(idx) -- want \(want[idx]), got \(got[idx])")
        }
    }
    
    static var randomColors: AnySequence<[Float]> {
        return AnySequence {
            return AnyIterator {
                [
                    Float.random(in: 0 ... 1),
                    Float.random(in: 0 ... 1),
                    Float.random(in: 0 ... 1),
                    1
                ]
            }
        }
    }
    
    private func assertRoundTripWorks(_ color: [Float], line: UInt = #line, message: @autoclosure () -> String = "") throws {
        let device = try XCTUnwrap(device)
        let texture = try XCTUnwrap(texture)
        let commandQueue = try XCTUnwrap(commandQueue)
        let library = try XCTUnwrap(library)
        let commandBuffer = try XCTUnwrap(commandQueue.makeCommandBuffer())
        var rgba = color
        let region = MTLRegionMake2D(0, 0, 1, 1)
        let bytesPerRow: Int = MemoryLayout<Float>.size * 4 * 1
        texture.replace(region: region, mipmapLevel: 0, withBytes: &rgba, bytesPerRow: bytesPerRow)
        try NTSCTextureFilter.convertToYIQ(
            texture,
            library: try XCTUnwrap(library),
            commandBuffer: commandBuffer,
            device: device
        )
        try NTSCTextureFilter.convertToRGB(texture, commandBuffer: commandBuffer, library: library, device: device)
        
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        // Expecting not to lose any precision when moving back and forth
        let want: [Float] = color
        var got: [Float] = [0, 0, 0, 0]
        texture.getBytes(&got, bytesPerRow: bytesPerRow, from: region, mipmapLevel: 0)
        for idx in color.indices {
            XCTAssertEqual(want[idx], got[idx], accuracy: 0.001, message(), line: line)
        }
    }
    
    func testRGBRoundTripInGeneral() throws {
        for color in Self.randomColors.prefix(1_000) {
            try assertRoundTripWorks(color, message: "Mixmatch for color \(color)")
        }
    }
    
    func testIFullButterworthChromaLowpass() throws {
        let device = try XCTUnwrap(device)
        let texture = try XCTUnwrap(texture)
        let commandQueue = try XCTUnwrap(commandQueue)
        let library = try XCTUnwrap(library)
        let commandBuffer = try XCTUnwrap(commandQueue.makeCommandBuffer())
        var yiqa = [0.5, 0.5, 0.5, 1]
        let region = MTLRegionMake2D(0, 0, 1, 1)
        let bytesPerRow: Int = MemoryLayout<Float>.size * 4 * 1
        texture.replace(region: region, mipmapLevel: 0, withBytes: &yiqa, bytesPerRow: bytesPerRow)
        let iFunction = IIRTransferFunction.butterworth(cutoff: 1_300_000, rate: NTSC.rate * 1)
        let numerators = iFunction.numerators
        let denominators = iFunction.denominators
        
        // From Rust
        XCTAssertEqual(numerators, [0.0572976321, 0.114595264, 0.0572976321])
        XCTAssertEqual(denominators, [1, -1.218135, 0.447325468])
                                              
        let iFilter = IIRTextureFilter(
            device: device,
            library: library,
            numerators: numerators,
            denominators: denominators,
            initialCondition: .zero,
            channel: .i,
            scale: 1,
            delay: 2
        )
        try iFilter.run(outputTexture: texture, commandBuffer: commandBuffer)
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        // Sampled from Swift, no idea if this is right
        let z0 = iFilter.zTextures[0].pixelValue(x: 0, y: 0)
        let z1 = iFilter.zTextures[1].pixelValue(x: 0, y: 0)
        let z2 = iFilter.zTextures[2].pixelValue(x: 0, y: 0)
        let iValuesInZ = [z0, z1, z2].map({ $0[1] })    // y[i]qa
        let expectedIValuesInZ: [Float] = [2.74764766E-9, 4.71874206E-10, 0]
        XCTAssertEqual(iValuesInZ, expectedIValuesInZ)
    }
    
    func testIFullButterworthFullRun() throws {
        let device = try XCTUnwrap(device)
        let texture = try XCTUnwrap(texture)
        let commandQueue = try XCTUnwrap(commandQueue)
        let library = try XCTUnwrap(library)
        let buf0 = try XCTUnwrap(commandQueue.makeCommandBuffer())
        texture.paint(with: [0.498039246, 1.49011612E-8, 1.49011612E-8])
        let initialConditionTexture = try XCTUnwrap(IIRTextureFilter.texture(
            width: texture.width,
            height: texture.height,
            pixelFormat: texture.pixelFormat,
            device: device)
        )
        let zTextures = Array(IIRTextureFilter.textures(
            width: texture.width,
            height: texture.height,
            pixelFormat: texture.pixelFormat,
            device: device)
            .prefix(3)
        )
        let transferFunction = IIRTransferFunction.butterworth(cutoff: 1_300_000, rate: NTSC.rate * 1)
        let numerators = transferFunction.numerators
        let denominators = transferFunction.denominators
        try IIRTextureFilter.fillTexturesForInitialCondition(
            outputTexture: texture,
            initialCondition: .zero,
            initialConditionTexture: initialConditionTexture,
            textures: zTextures,
            numerators: numerators,
            denominators: denominators,
            library: library,
            device: device,
            commandBuffer: buf0
        )
        buf0.commit()
        buf0.waitUntilCompleted()
        var z0 = zTextures[0].pixelValue(x: 0, y: 0)
        XCTAssertEqual(z0, [0, 0, 0, 1])
        var z1 = zTextures[1].pixelValue(x: 0, y: 0)
        XCTAssertEqual(z1, [0, 0, 0, 1])
        var z2 = zTextures[2].pixelValue(x: 0, y: 0)
        XCTAssertEqual(z2, [0, 0, 0, 1])
        
        let buf1 = try XCTUnwrap(commandQueue.makeCommandBuffer())
        
        try IIRTextureFilter.filterSample(
            texture,
            zTex0: zTextures[0], 
            filteredSampleTexture: initialConditionTexture,
            num0: numerators[0],
            library: library,
            device: device, 
            commandBuffer: buf1
        )
        buf1.commit()
        buf1.waitUntilCompleted()
        let filteredSample = initialConditionTexture.pixelValue(x: 0, y: 0)
        
        // From Rust
        XCTAssertEqual(filteredSample[1], 8.53801251E-10)
        
        let buf2 = try XCTUnwrap(commandQueue.makeCommandBuffer())
        
        for i in numerators.indices {
            let nextIdx = i + 1
            guard nextIdx < numerators.count else {
                break
            }
            let z = zTextures[i]
            let zPlusOne = zTextures[nextIdx]
            try IIRTextureFilter.sideEffect(
                inputImage: texture,
                z: z,
                zPlusOne: zPlusOne,
                filteredSample: initialConditionTexture,
                numerator: numerators[nextIdx],
                denominator: denominators[nextIdx],
                library: library,
                device: device,
                commandBuffer: buf2
            )
        }
        buf2.commit()
        buf2.waitUntilCompleted()
        
        z0 = zTextures[0].pixelValue(x: 0, y: 0)
        XCTAssertEqual(z0[1], 2.74764766E-9)
        z1 = zTextures[1].pixelValue(x: 0, y: 0)
        XCTAssertEqual(z1[1], 4.71874206E-10)
        z2 = zTextures[2].pixelValue(x: 0, y: 0)
        XCTAssertEqual(z2[1], 0)
        
        let buf3 = try XCTUnwrap(commandQueue.makeCommandBuffer())
        try IIRTextureFilter.finalImage(
            inputImage: texture,
            filteredImage: initialConditionTexture,
            scale: 1,
            library: library,
            device: device,
            commandBuffer: buf3
        )
        buf3.commit()
        buf3.waitUntilCompleted()
        
        let filtered = initialConditionTexture.pixelValue(x: 0, y: 0)
        // from Rust
        XCTAssertEqual(filtered[1], 8.53801474E-10)
        
        let buf4 = try XCTUnwrap(commandQueue.makeCommandBuffer())
        try IIRTextureFilter.compose(
            inputImage: texture,
            filteredImage: initialConditionTexture,
            channel: .i,
            library: library,
            device: device,
            commandBuffer: buf4)
        
        buf4.commit()
        buf4.waitUntilCompleted()
        let composed = initialConditionTexture.pixelValue(x: 0, y: 0)
        XCTAssertEqual(composed, [0.498039246, 7.42032923E-9, 1.49011612E-8])
    }
}
