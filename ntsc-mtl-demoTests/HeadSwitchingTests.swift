//
//  HeadSwitchingTests.swift
//  ntsc-mtl-demoTests
//
//  Created by Jeffrey Blagdon on 2024-06-08.
//

import XCTest
import CoreImage
@testable import ntsc_mtl_demo

final class HeadSwitchingTests: XCTestCase {
    private var device: MTLDevice!
    private var library: MTLLibrary!
    private var commandQueue: MTLCommandQueue!
    private var ciContext: CIContext!
    private var pipelineCache: MetalPipelineCache!
    private var filter: HeadSwitchingTextureFilter!

    override func setUpWithError() throws {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        self.device = device
        let library = try XCTUnwrap(device.makeDefaultLibrary())
        self.library = library
        let pipelineCache = try MetalPipelineCache(device: device, library: library)
        let commandQueue = try XCTUnwrap(device.makeCommandQueue())
        self.commandQueue = commandQueue
        let ciContext = CIContext(mtlCommandQueue: commandQueue)
        self.ciContext = ciContext
        let filter = HeadSwitchingTextureFilter(device: device, library: library, ciContext: ciContext, pipelineCache: pipelineCache)
        self.filter = filter
    }

    override func tearDownWithError() throws {
        pipelineCache = nil
        filter = nil
        ciContext = nil
        commandQueue = nil
        library = nil
        device = nil
    }
    
    func testBigOffset() throws {
        let image = try CIImage.videoFrame()
        try CIImage.saveToDisk(image, filename: "input", context: ciContext)
        let commandBuffer = try XCTUnwrap(commandQueue.makeCommandBuffer())
        var headSwitching: HeadSwitchingSettings = .default
        headSwitching.offset = 100
        headSwitching.horizShift = 100
        headSwitching.height = 200
        headSwitching.midLine = nil
        filter.headSwitchingSettings = headSwitching
        
        let inputTexture = try textureForImage(image, device: device)
        ciContext.render(image, to: inputTexture, commandBuffer: commandBuffer, bounds: image.extent, colorSpace: ciContext.workingColorSpace ?? CGColorSpaceCreateDeviceRGB())
        let outputTexture = try textureForImage(image, device: device)
        try filter.run(inputTexture: inputTexture, outputTexture: outputTexture, commandBuffer: commandBuffer)
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        let outputImage = try XCTUnwrap(CIImage(mtlTexture: outputTexture))
        try CIImage.saveToDisk(outputImage, filename: "output", context: ciContext)
    }
}
