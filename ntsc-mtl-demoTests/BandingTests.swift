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
    var image: CIImage!
    var device: MTLDevice!
    var library: MTLLibrary!
    var pipelineCache: MetalPipelineCache!
    var commandQueue: MTLCommandQueue!
    var ciContext: CIContext!
    var filter: NTSCTextureFilter!

    override func setUpWithError() throws {
        self.image = try CIImage.videoFrame()
        let effect: NTSCEffect = .default
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        self.device = device
        let library = try XCTUnwrap(device.makeDefaultLibrary())
        self.library = library
        self.pipelineCache = try MetalPipelineCache(device: device, library: library)
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
        self.pipelineCache = nil
        self.library = nil
        self.device = nil
        self.image = nil
    }

    func testApplyingFilter() throws {
        self.filter.inputImage = image
        // Got some banding already
        let outputImage = try XCTUnwrap(self.filter.outputImage)
        XCTAssertEqual(Int(outputImage.extent.height), 4032)
    }
    
    func outputImage(for inputImage: CIImage) throws -> CIImage {
        let commandBuffer = try XCTUnwrap(commandQueue.makeCommandBuffer())
        let textureA = try XCTUnwrap(IIRTextureFilter.texture(width: Int(inputImage.extent.width), height: Int(inputImage.extent.height), pixelFormat: .rgba16Float, device: device))
        let textureB = try XCTUnwrap(IIRTextureFilter.texture(from: textureA, device: device))
        
        ciContext.render(inputImage, to: textureA, commandBuffer: commandBuffer, bounds: inputImage.extent, colorSpace: ciContext.workingColorSpace ?? CGColorSpaceCreateDeviceRGB())
        try NTSCTextureFilter.convertToYIQ(textureA, output: textureB, library: library, commandBuffer: commandBuffer, device: device, pipelineCache: pipelineCache)
        
        let function = IIRTransferFunction.lowpassFilter(cutoff: 1_300_000, rate: NTSC.rate * 1)
        let fullIButterworthFilter = IIRTextureFilter(device: device, library: library, pipelineCache: pipelineCache, numerators: function.numerators, denominators: function.denominators, initialCondition: .zero, channels: .i, scale: 1, delay: 2)
        try fullIButterworthFilter.run(inputTexture: textureB, outputTexture: textureA, commandBuffer: commandBuffer)
        try NTSCTextureFilter.convertToRGB(textureA, output: textureB, commandBuffer: commandBuffer, library: library, device: device, pipelineCache: pipelineCache)
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        return try XCTUnwrap(CIImage(mtlTexture: textureB))
    }
    
    func testApplyingChroma() throws {
        let outputImage = try outputImage(for: image)
        XCTAssertEqual(Int(outputImage.extent.width), 3024)
    }
    
    func testApplyingChromaToPlainWhiteImage() throws {
        let strideSize: CGFloat = 0.2
        let rangeStart: CGFloat = 0
        let rangeEnd: CGFloat = 1
        for r in stride(from: rangeStart, to: rangeEnd, by: strideSize) {
            for g in stride(from: rangeStart, to: rangeEnd, by: strideSize) {
                for b in stride(from: rangeStart, to: rangeEnd, by: strideSize) {
                    let image = CIImage.testImage(color: CIColor(red: r, green: g, blue: b), size: CGSize(width: 1000, height: 1000))
                    let outputImage = try outputImage(for: image)
                    try CIImage.saveToDisk(outputImage, filename: "red: \(Int(r * 100)) green: \(Int(g * 100)) blue: \(Int(b * 100))", context: ciContext)
                    XCTAssertEqual(Int(outputImage.extent.width), 1000)
                }
            }
        }
    }
    
    struct FillTexturesResult {
        var rgbInput: CIImage
        var initialCondition: CIImage
        var tempZ0: CIImage
        var z: [CIImage]
    }
    
    struct InitialConditionFillOnlyResult {
        var rgbInput: CIImage
        var z0: CIImage
        var zI: CIImage
    }
    
    func fillTexturesForInitialCondition(image: CIImage) throws -> FillTexturesResult {
        let commandBuffer = try XCTUnwrap(commandQueue.makeCommandBuffer())
        let rgbInputTexture = try XCTUnwrap(IIRTextureFilter.texture(width: Int(image.extent.width), height: Int(image.extent.height), pixelFormat: .rgba16Float, device: device))
        ciContext.render(image, to: rgbInputTexture, commandBuffer: commandBuffer, bounds: image.extent, colorSpace: ciContext.workingColorSpace ?? CGColorSpaceCreateDeviceRGB())
        let initialConditionTexture = try XCTUnwrap(IIRTextureFilter.texture(from: rgbInputTexture, device: device))
        let tempZ0Texture = try XCTUnwrap(IIRTextureFilter.texture(from: rgbInputTexture, device: device))
        let function = IIRTransferFunction.lowpassFilter(cutoff: 1_300_000, rate: NTSC.rate * 1)
        let zTextures = Array(IIRTextureFilter.textures(from: rgbInputTexture, device: device).prefix(function.numerators.count))
        
        let fullIButterworthFilter = IIRTextureFilter(device: device, library: library, pipelineCache: pipelineCache, numerators: function.numerators, denominators: function.denominators, initialCondition: .zero, channels: .i, scale: 1, delay: 2)
        try IIRTextureFilter.fillTexturesForInitialCondition(
            inputTexture: rgbInputTexture,
            initialCondition: .zero,
            initialConditionTexture: initialConditionTexture,
            tempZ0Texture: tempZ0Texture,
            zTextures: zTextures,
            numerators: function.numerators,
            denominators: function.denominators,
            library: library,
            device: device, 
            pipelineCache: pipelineCache,
            commandBuffer: commandBuffer)
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        let rgbInputImage = try XCTUnwrap(CIImage(mtlTexture: rgbInputTexture))
        let initialConditionImage = try XCTUnwrap(CIImage(mtlTexture: initialConditionTexture))
        let tempZ0Image = try XCTUnwrap(CIImage(mtlTexture: tempZ0Texture))
        let zImages = try zTextures.map { try XCTUnwrap(CIImage(mtlTexture: $0)) }
        return FillTexturesResult(rgbInput: rgbInputImage, initialCondition: initialConditionImage, tempZ0: tempZ0Image, z: zImages)
    }
    
    func initialConditionFillOnly(image: CIImage, index: Int, function: IIRTransferFunction) throws -> InitialConditionFillOnlyResult {
        let commandBuffer = try XCTUnwrap(commandQueue.makeCommandBuffer())
        let rgbInputTexture = try XCTUnwrap(IIRTextureFilter.texture(width: Int(image.extent.width), height: Int(image.extent.height), pixelFormat: .rgba16Float, device: device))
        ciContext.render(image, to: rgbInputTexture, commandBuffer: commandBuffer, bounds: image.extent, colorSpace: ciContext.workingColorSpace ?? CGColorSpaceCreateDeviceRGB())
        let zTex0 = try XCTUnwrap(IIRTextureFilter.texture(from: rgbInputTexture, device: device))
        let zTexI = try XCTUnwrap(IIRTextureFilter.texture(from: rgbInputTexture, device: device))
        let initialConditionTexture = try XCTUnwrap(IIRTextureFilter.texture(from: rgbInputTexture, device: device))
        
        let firstNonzeroCoeff = try XCTUnwrap(function.denominators.first(where: { !$0.isZero }))
        let normalizedNumerators = function.numerators.map { num in
            num / firstNonzeroCoeff
        }
        let normalizedDenominators = function.denominators.map { denom in
            denom / firstNonzeroCoeff
        }
        
        var aSum: Float = 1
        var cSum: Float = 0
        var bSum: Float = 0
        for i in 1 ..< function.numerators.count {
            let num = normalizedNumerators[i]
            let den = normalizedDenominators[i]
            bSum += num - (den * normalizedNumerators[0])
        }
        let z0Fill = bSum / normalizedDenominators.reduce(0, +)
        var z0FillValues: [Float16] = [z0Fill, z0Fill, z0Fill, 1].map(Float16.init)
        try IIRTextureFilter.paint(texture: zTex0, with: z0FillValues, library: library, device: device, pipelineCache: pipelineCache, commandBuffer: commandBuffer)
        
        try IIRTextureFilter.initialConditionFill(initialConditionTex: initialConditionTexture, zTex0: zTex0, zTexToFill: zTexI, aSum: aSum, cSum: cSum, library: library, device: device, pipelineCache: pipelineCache, commandBuffer: commandBuffer)
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        let rgbInputImage = try XCTUnwrap(CIImage(mtlTexture: rgbInputTexture))
        let z0Image = try XCTUnwrap(CIImage(mtlTexture: zTex0))
        let zTexIImage = try XCTUnwrap(CIImage(mtlTexture: zTexI))
        return InitialConditionFillOnlyResult(rgbInput: rgbInputImage, z0: z0Image, zI: zTexIImage)
    }
    
    func initialZ0FillOnly(image: CIImage, index: Int, function: IIRTransferFunction) throws -> CIImage {
        let zTex0 = try XCTUnwrap(IIRTextureFilter.texture(
            width: Int(image.extent.width), height:Int(image.extent.height),
            pixelFormat: .rgba16Float,
            device: device)
        )
        
        let firstNonzeroCoeff = try XCTUnwrap(function.denominators.first(where: { !$0.isZero }))
        let normalizedNumerators = function.numerators.map { num in
            num / firstNonzeroCoeff
        }
        let normalizedDenominators = function.denominators.map { denom in
            denom / firstNonzeroCoeff
        }
        
        var bSum: Float = 0
        for i in 1 ..< function.numerators.count {
            let num = normalizedNumerators[i]
            let den = normalizedDenominators[i]
            bSum += num - (den * normalizedNumerators[0])
        }
        let z0Fill = bSum / normalizedDenominators.reduce(0, +)
        var z0FillValues: [Float16] = [z0Fill, z0Fill, z0Fill, 1].map(Float16.init)
        let commandBuffer = try XCTUnwrap(commandQueue.makeCommandBuffer())
        try IIRTextureFilter.paint(texture: zTex0, with: z0FillValues, library: library, device: device, pipelineCache: pipelineCache, commandBuffer: commandBuffer)
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        return try XCTUnwrap(CIImage(mtlTexture: zTex0))
    }
    
    func testInitialZ0Only() throws {
        let image = CIImage.testImage(color: CIColor(red: 0.0, green: 0.0, blue: 0.6, alpha: 1.0))
        let function = IIRTransferFunction.lowpassFilter(cutoff: 1_300_000, rate: NTSC.rate * 1)
        let outputImage = try initialZ0FillOnly(image: image, index: 0, function: function)
        try CIImage.saveToDisk(outputImage, filename: "z0-only", context: ciContext)
    }
    
    // Write tests for each individual phase. We don't care how crazy the output looks, we only care if we see the banding
    
    func testFillingForInitialCondition() throws {
        let image = CIImage.testImage(color: CIColor(red: 0.0, green: 0.0, blue: 0.6, alpha: 1.0), size: CGSize(width: 1000, height: 1000))
        let result = try fillTexturesForInitialCondition(image: image)
        try CIImage.saveToDisk(result.rgbInput, filename: "rgbInput", context: ciContext)
        try CIImage.saveToDisk(result.initialCondition, filename: "initialCondition", context: ciContext)
        try CIImage.saveToDisk(result.tempZ0, filename: "tempZ0", context: ciContext)
        for (idx, img) in result.z.enumerated() {
            try CIImage.saveToDisk(img, filename: "z-\(idx)", context: ciContext)
        }
    }
    
    func testInitialFillOnly() throws {
        let image = CIImage.testImage(color: CIColor(red: 0.0, green: 0.0, blue: 0.6, alpha: 1.0), size: CGSize(width: 1000, height: 1000))
        let function = IIRTransferFunction.lowpassFilter(cutoff: 1_300_000, rate: NTSC.rate * 1)
        for idx in function.numerators.indices {
            let result = try initialConditionFillOnly(image: image, index: idx, function: function)
            try CIImage.saveToDisk(result.rgbInput, filename: "rgbInput-\(idx)", context: ciContext)
            try CIImage.saveToDisk(result.z0, filename: "z0-\(idx)", context: ciContext)
            try CIImage.saveToDisk(result.zI, filename: "zI-\(idx)", context: ciContext)
        }
    }
}
