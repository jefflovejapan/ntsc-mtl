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
    
    private var library: MTLLibrary!
    private var texture: MTLTexture!
    private var device: MTLDevice!
    private var ciContext: CIContext!
    private var pipelineCache: MetalPipelineCache!
    private var commandQueue: MTLCommandQueue!

    override func setUpWithError() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw Error.noDevice
        }
        self.device = device
        self.ciContext = CIContext(mtlDevice: device)
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba16Float, width: 1, height: 1, mipmapped: false)
        self.texture = device.makeTexture(descriptor: textureDescriptor)
        self.commandQueue = try XCTUnwrap(device.makeCommandQueue())
        let library = try XCTUnwrap(device.makeDefaultLibrary())
        self.library = library
        self.pipelineCache = try MetalPipelineCache(device: device, library: library)
    }
    
    override func tearDownWithError() throws {
        self.pipelineCache = nil
        self.library = nil
        self.commandQueue = nil
        self.texture = nil
        self.ciContext = nil
        self.device = nil
    }
    
    func testMetalRoundTrip() throws {
        let texture = try XCTUnwrap(texture)
        let input: [Float16] = [0.5, 0.5, 0.5, 1]
        var rgba = input
        let region = MTLRegionMake2D(0, 0, 1, 1)
        let bytesPerRow: Int = MemoryLayout<Float16>.size * 4 * 1
        texture.replace(region: region, mipmapLevel: 0, withBytes: &rgba, bytesPerRow: bytesPerRow)
        var newValue: [Float16] = [0, 0, 0, 0]
        texture.getBytes(&newValue, bytesPerRow: bytesPerRow, from: region, mipmapLevel: 0)
        XCTAssertEqual(rgba, input)
        XCTAssertEqual(newValue, input)
    }
    
    private func assertArraysEqual(lhs: [Float16], rhs: [Float16], accuracy: Float16 = 0.001, message: @autoclosure () -> String = "", line: UInt = #line) {
        for (idx, (l, r)) in zip(lhs, rhs).enumerated() {
            XCTAssertEqual(l, r, accuracy: accuracy, message(), line: line)
        }
    }
    
    func testYIQConversion() throws {
        let outputTexture = try XCTUnwrap(IIRTextureFilter.texture(from: texture, device: device))
        let commandBuffer = try XCTUnwrap(commandQueue.makeCommandBuffer())
        let input: [Float16] = [0.5, 0.5, 0.5, 1]
        var rgba = input
        let region = MTLRegionMake2D(0, 0, 1, 1)
        let bytesPerRow: Int = MemoryLayout<Float16>.size * 4 * 1
        texture.replace(region: region, mipmapLevel: 0, withBytes: &rgba, bytesPerRow: bytesPerRow)
        try NTSCTextureFilter.convertToYIQ(
            texture, 
            output: outputTexture,
            commandBuffer: commandBuffer,
            device: device, 
            pipelineCache: pipelineCache
        )
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        // from Rust
        let want: [Float16] = [0.5, 0, 0, 1]
        var got: [Float16] = [0, 0, 0, 0]
        outputTexture.getBytes(&got, bytesPerRow: bytesPerRow, from: region, mipmapLevel: 0)
        assertArraysEqual(lhs: want, rhs: got)
    }
    
    func testRGBConversion() throws {
        let outputTexture = try XCTUnwrap(IIRTextureFilter.texture(from: texture, device: device))
        let buf0 = try XCTUnwrap(commandQueue.makeCommandBuffer())
        let input: [Float16] = [0.5, 0.5, 0.5, 1]
        try IIRTextureFilter.paint(
            texture: texture,
            with: input,
            device: device,
            pipelineCache: pipelineCache,
            commandBuffer: buf0
        )
        try NTSCTextureFilter.convertToRGB(
            texture,
            output: outputTexture,
            commandBuffer: buf0,
            device: device,
            pipelineCache: pipelineCache
        )
        buf0.commit()
        buf0.waitUntilCompleted()
        // from Rust
        let want: [Float16] = [1.2875, 0.040499985, 0.7985, 1]
        let got = outputTexture.pixelValue(x: 0, y: 0)
        assertArraysEqual(lhs: want, rhs: got)
    }
    
    func testRGBRoundTrip() throws {
        let yiqTexture = try XCTUnwrap(IIRTextureFilter.texture(from: texture, device: device))
        let rgbTexture = try XCTUnwrap(IIRTextureFilter.texture(from: texture, device: device))
        let commandBuffer = try XCTUnwrap(commandQueue.makeCommandBuffer())
        let input: [Float16] = [0.5, 0.5, 0.5, 1]
        var rgba = input
        let region = MTLRegionMake2D(0, 0, 1, 1)
        let bytesPerRow: Int = MemoryLayout<Float16>.size * 4 * 1
        texture.replace(region: region, mipmapLevel: 0, withBytes: &rgba, bytesPerRow: bytesPerRow)
        try NTSCTextureFilter.convertToYIQ(
            texture, output: yiqTexture,
            commandBuffer: commandBuffer,
            device: device,
            pipelineCache: pipelineCache)
        try NTSCTextureFilter.convertToRGB(
            yiqTexture,
            output: rgbTexture,
            commandBuffer: commandBuffer,
            device: device,
            pipelineCache: pipelineCache
        )
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        // Expecting not to lose any precision when moving back and forth
        let want: [Float16] = input
        var got: [Float16] = [0, 0, 0, 0]
        rgbTexture.getBytes(&got, bytesPerRow: bytesPerRow, from: region, mipmapLevel: 0)
        assertArraysEqual(lhs: want, rhs: got)
    }
    
    static var randomColors: AnySequence<[Float16]> {
        return AnySequence {
            return AnyIterator {
                [
                    Float16.random(in: 0 ... 1),
                    Float16.random(in: 0 ... 1),
                    Float16.random(in: 0 ... 1),
                    1
                ]
            }
        }
    }
    
    private func assertRoundTripWorks(_ color: [Float16], line: UInt = #line, message: @autoclosure () -> String = "") throws {
        let yiqTexture = try XCTUnwrap(IIRTextureFilter.texture(from: texture, device: device))
        let rgbTexture = try XCTUnwrap(IIRTextureFilter.texture(from: texture, device: device))
        let commandBuffer = try XCTUnwrap(commandQueue.makeCommandBuffer())
        var rgba = color
        let region = MTLRegionMake2D(0, 0, 1, 1)
        let bytesPerRow: Int = MemoryLayout<Float16>.size * 4 * 1
        texture.replace(region: region, mipmapLevel: 0, withBytes: &rgba, bytesPerRow: bytesPerRow)
        try NTSCTextureFilter.convertToYIQ(
            texture,
            output: yiqTexture,
            commandBuffer: commandBuffer,
            device: device, 
            pipelineCache: pipelineCache
        )
        try NTSCTextureFilter.convertToRGB(
            yiqTexture,
            output: rgbTexture,
            commandBuffer: commandBuffer,
            device: device,
            pipelineCache: pipelineCache
        )
        
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        // Expecting not to lose any precision when moving back and forth
        let want: [Float16] = color
        var got: [Float16] = [0, 0, 0, 0]
        rgbTexture.getBytes(&got, bytesPerRow: bytesPerRow, from: region, mipmapLevel: 0)
        assertArraysEqual(lhs: want, rhs: got, accuracy: 0.005, message: message())
    }
    
    func testRGBRoundTripInGeneral() throws {
        for color in Self.randomColors.prefix(1_000) {
            try assertRoundTripWorks(color, message: "Mixmatch for color \(color)")
        }
    }
    
    private func assertInYIQBounds(pixel: [Float16], message: @autoclosure () -> String = "", line: UInt = #line) {
        let yRange: ClosedRange<Float16> = -1 ... 1
        let iRange: ClosedRange<Float16> = -0.5957 ... 0.5957
        let qRange: ClosedRange<Float16> = -0.5226 ... 0.5226
        XCTAssert(yRange.contains(pixel[0]), message(), line: line)
        XCTAssert(iRange.contains(pixel[1]), message(), line: line)
        XCTAssert(qRange.contains(pixel[2]), message(), line: line)
    }
    
    func testYIQIsInBounds() throws {
        let outputTexture = try XCTUnwrap(IIRTextureFilter.texture(width: texture.width, height: texture.height, pixelFormat: texture.pixelFormat, device: device))
        for color in Self.randomColors.prefix(1_000) {
            let commandBuffer = try XCTUnwrap(commandQueue.makeCommandBuffer())
            try IIRTextureFilter.paint(
                texture: texture,
                with: color,
                device: device,
                pipelineCache: pipelineCache,
                commandBuffer: commandBuffer
            )
            try NTSCTextureFilter.convertToYIQ(
                texture,
                output: outputTexture,
                commandBuffer: commandBuffer,
                device: device,
                pipelineCache: pipelineCache
            )
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
            let output = outputTexture.pixelValue(x: 0, y: 0)
            assertInYIQBounds(pixel: output)
        }
    }
    
    func testIFullButterworthChromaLowpass() throws {
        let commandBuffer = try XCTUnwrap(commandQueue.makeCommandBuffer())
        var yiqa = [0.5, 0.5, 0.5, 1]
        let region = MTLRegionMake2D(0, 0, 1, 1)
        let bytesPerRow: Int = MemoryLayout<Float16>.size * 4 * 1
        texture.replace(region: region, mipmapLevel: 0, withBytes: &yiqa, bytesPerRow: bytesPerRow)
        let iFunction = IIRTransferFunction.butterworth(cutoff: 1_300_000, rate: NTSC.rate * 1)
        let numerators = iFunction.numerators
        let denominators = iFunction.denominators
        
        // From Rust
        XCTAssertEqual(numerators, [0.0572976321, 0.114595264, 0.0572976321])
        XCTAssertEqual(denominators, [1, -1.218135, 0.447325468])
                                              
        let iFilter = IIRTextureFilter(
            device: device,
            pipelineCache: pipelineCache,
            numerators: numerators,
            denominators: denominators,
            initialCondition: .zero,
            channels: .i,
            scale: 1,
            delay: 2
        )
        let outputTexture = try XCTUnwrap(IIRTextureFilter.texture(width: texture.width, height: texture.height, pixelFormat: texture.pixelFormat, device: device))
        try iFilter.run(inputTexture: texture, outputTexture: outputTexture, commandBuffer: commandBuffer)
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        // Sampled from Swift, no idea if this is right
        let z0 = iFilter.zTextures[0].pixelValue(x: 0, y: 0)
        let z1 = iFilter.zTextures[1].pixelValue(x: 0, y: 0)
        let z2 = iFilter.zTextures[2].pixelValue(x: 0, y: 0)
        let iValuesInZ = [z0, z1, z2].map({ $0[1] })    // y[i]qa
        let expectedIValuesInZ: [Float16] = [0, 0, 0]
        assertArraysEqual(lhs: iValuesInZ, rhs: expectedIValuesInZ)
    }
    
    func testIFullButterworthFullRun() throws {
        let buf0 = try XCTUnwrap(commandQueue.makeCommandBuffer())
        let initialFill: [Float16] = [0.498039246, 0, 0, 1]
        try IIRTextureFilter.paint(
            texture: texture,
            with: initialFill,
            device: device,
            pipelineCache: pipelineCache,
            commandBuffer: buf0
        )
        let initialConditionTexture = try XCTUnwrap(IIRTextureFilter.texture(
            from: texture,
            device: device
        ))
        let tempZ0Texture = try XCTUnwrap(IIRTextureFilter.texture(from: texture, device: device))
        let zTextures = Array(
            IIRTextureFilter.textures(
                from: texture,
                device: device
            )
            .prefix(3)
        )
        let transferFunction = IIRTransferFunction.butterworth(cutoff: 1_300_000, rate: NTSC.rate * 1)
        let numerators = transferFunction.numerators
        let denominators = transferFunction.denominators
        try IIRTextureFilter.fillTexturesForInitialCondition(
            inputTexture: texture,
            initialCondition: .zero,
            initialConditionTexture: initialConditionTexture,
            tempZ0Texture: tempZ0Texture,
            zTextures: zTextures,
            numerators: numerators,
            denominators: denominators,
            device: device,
            pipelineCache: pipelineCache,
            commandBuffer: buf0
        )

        buf0.commit()
        buf0.waitUntilCompleted()
        var tex = texture.pixelValue(x: 0, y: 0)
        assertArraysEqual(lhs: tex, rhs: initialFill)
        var z0 = zTextures[0].pixelValue(x: 0, y: 0)
        assertArraysEqual(lhs: z0, rhs: [0, 0, 0, 1])
        var z1 = zTextures[1].pixelValue(x: 0, y: 0)
        assertArraysEqual(lhs: z1, rhs: [0, 0, 0, 1])
        var z2 = zTextures[2].pixelValue(x: 0, y: 0)
        assertArraysEqual(lhs: z2, rhs: [0, 0, 0, 1])
        
        let buf1 = try XCTUnwrap(commandQueue.makeCommandBuffer())
        
        let tempZ0Tex = try XCTUnwrap(IIRTextureFilter.texture(from: texture, device: device))
        let filteredSampleTex = try XCTUnwrap(IIRTextureFilter.texture(from: texture, device: device))
        
        try IIRTextureFilter.filterSample(
            inputTexture: texture,
            zTex0: zTextures[0],
            filteredSampleTexture: filteredSampleTex,
            num0: numerators[0],
            device: device,
            pipelineCache: pipelineCache,
            commandBuffer: buf1
        )
        buf1.commit()
        buf1.waitUntilCompleted()
        tex = filteredSampleTex.pixelValue(x: 0, y: 0)
        let filteredSample = filteredSampleTex.pixelValue(x: 0, y: 0)
        
//        From Rust
        assertArraysEqual(lhs: filteredSample, rhs: [0.028536469, 0, 0, 1])

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
                filteredSample: filteredSampleTex,
                numerator: numerators[nextIdx],
                denominator: denominators[nextIdx],
                device: device,
                pipelineCache: pipelineCache,
                commandBuffer: buf2
            )
        }
        buf2.commit()
        buf2.waitUntilCompleted()
        tex = texture.pixelValue(x: 0, y: 0)
        assertArraysEqual(lhs: tex, rhs: initialFill)
        z0 = zTextures[0].pixelValue(x: 0, y: 0)
        assertArraysEqual(lhs: z0, rhs: [0.09183421, 2.7476477e-09, 2.7476477e-09, 1.0])
        z1 = zTextures[1].pixelValue(x: 0, y: 0)
        assertArraysEqual(lhs: z1, rhs: [0.01577138, 4.718742e-10, 4.718742e-10, 1.0])
        z2 = zTextures[2].pixelValue(x: 0, y: 0)
        assertArraysEqual(lhs: z2, rhs: [0.0, 0.0, 0.0, 1.0])
        
        let buf3 = try XCTUnwrap(commandQueue.makeCommandBuffer())
//        try IIRTextureFilter.finalImage(
//            inputImage: texture,
//            filteredImage: initialConditionTexture,
//            scale: 1,
//            library: library,
//            device: device,
//            commandBuffer: buf3
//        )
        let filteredImageTexture = try XCTUnwrap(IIRTextureFilter.texture(from: texture, device: device))
        try IIRTextureFilter.filterImage(
            inputImage: texture,
            filteredSample: filteredSampleTex,
            outputTexture: filteredImageTexture,
            scale: 1,
            device: device,
            pipelineCache: pipelineCache,
            commandBuffer: buf3
        )
        buf3.commit()
        buf3.waitUntilCompleted()
        tex = texture.pixelValue(x: 0, y: 0)
        assertArraysEqual(lhs: tex, rhs: initialFill)
        
        let filtered = filteredImageTexture.pixelValue(x: 0, y: 0)
        // from Rust
        assertArraysEqual(lhs: filtered, rhs: [0.028536469, 8.538015e-10, 8.538015e-10, 1.0])
        let input = texture.pixelValue(x: 0, y: 0)
        
        // Why does texture have 0 alpha???
        assertArraysEqual(lhs: input, rhs: [0.49803925, 1.4901161e-08, 1.4901161e-08, 1.0])
        
        let buf4 = try XCTUnwrap(commandQueue.makeCommandBuffer())
        let outputTexture = try XCTUnwrap(IIRTextureFilter.texture(width: texture.width, height: texture.height, pixelFormat: texture.pixelFormat, device: device))
        try IIRTextureFilter.finalCompose(
            inputImage: texture,
            filteredImage: filteredImageTexture,
            writingTo: outputTexture,
            channels: .i, 
            delay: 0,
            device: device,
            pipelineCache: pipelineCache,
            commandBuffer: buf4
        )
        
        buf4.commit()
        buf4.waitUntilCompleted()
        tex = texture.pixelValue(x: 0, y: 0)
        XCTAssertEqual(tex, initialFill)
        let got = outputTexture.pixelValue(x: 0, y: 0)
        // From Rust
        let want: [Float16] = [0.498039246, 0, 0, 1]
        assertArraysEqual(lhs: got, rhs: want)
    }
    
    func testYIQCompose() throws {
        let anotherTexture = try XCTUnwrap(IIRTextureFilter.texture(
            width: texture.width,
            height: texture.height,
            pixelFormat: texture.pixelFormat,
            device: device
        )
        )
        let outputTexture = try XCTUnwrap(IIRTextureFilter.texture(
            width: texture.width,
            height: texture.height,
            pixelFormat: texture.pixelFormat,
            device: device)
        )
        
        let buf0 = try XCTUnwrap(commandQueue.makeCommandBuffer())
        try IIRTextureFilter.paint(
            texture: texture,
            with: [0.0, 0.01, 0.02, 1],
            device: device,
            pipelineCache: pipelineCache,
            commandBuffer: buf0
        )
        try IIRTextureFilter.paint(
            texture: anotherTexture,
            with: [0.04, 0.05, 0.06, 1],
            device: device,
            pipelineCache: pipelineCache,
            commandBuffer: buf0
        )
        buf0.commit()
        buf0.waitUntilCompleted()
        let buf1 = try XCTUnwrap(commandQueue.makeCommandBuffer())
        try IIRTextureFilter.finalCompose(
            inputImage: texture,
            filteredImage: anotherTexture,
            writingTo: outputTexture,
            channels: .i, 
            delay: 0,
            device: device, 
            pipelineCache: pipelineCache,
            commandBuffer: buf1
        )
        buf1.commit()
        buf1.waitUntilCompleted()
        let composed = outputTexture.pixelValue(x: 0, y: 0)
        assertArraysEqual(lhs: composed, rhs: [0, 0.05, 0.02, 1])
    }
}
