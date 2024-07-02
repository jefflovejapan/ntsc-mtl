//
//  CIImage+TestImage.swift
//  ntsc-mtl-demoTests
//
//  Created by Jeffrey Blagdon on 2024-06-08.
//

import Foundation
import CoreImage
import XCTest

extension CIImage {
    static func testImage(color: CIColor, size: CGSize = CGSize(width: 1, height: 1)) -> CIImage {
        return CIImage(color: color).cropped(to: CGRect(origin: .zero, size: size))
    }
    
    static func videoFrame() throws -> CIImage {
        let imageURL = try XCTUnwrap(Bundle(for: BandingTests.self).url(forResource: "video-frame", withExtension: "jpg"))
        let imageData = try Data(contentsOf: imageURL)
        return try XCTUnwrap(CIImage(data: imageData))
    }
    
    static func saveToDisk(_ ciImage: CIImage, filename: String, context: CIContext) throws {
        // Convert CIImage to CGImage
        let cgImage = try XCTUnwrap(context.createCGImage(ciImage, from: ciImage.extent))
        let uiImage = UIImage(cgImage: cgImage)
        let data = try XCTUnwrap(uiImage.pngData())
        let url = try XCTUnwrap(FileManager.default.temporaryDirectory.appendingPathComponent(filename).appendingPathExtension("png"))
        try data.write(to: url)
        print("Wrote image to \(url.absoluteString)")
    }
}

