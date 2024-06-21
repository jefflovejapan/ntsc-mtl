//
//  PhaseNoiseTextureFilter.swift
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-06-12.
//

import Foundation
import Metal
import CoreImage
import CoreImage.CIFilterBuiltins

class PhaseNoiseTextureFilter {
//    typealias Error = TextureFilterError
//    private let device: MTLDevice
//    private let pipelineCache: MetalPipelineCache
//    private let ciContext: CIContext
//    var intensity: Float16 = NTSCEffect.default.chromaPhaseError
//    private var rng = SystemRandomNumberGenerator()
//    private let randomImageGenerator = CIFilter.randomGenerator()
//    private var randomTexture: MTLTexture?
//    
//    
//    init(device: MTLDevice, pipelineCache: MetalPipelineCache, ciContext: CIContext) {
//        self.device = device
//        self.pipelineCache = pipelineCache
//        self.ciContext = ciContext
//    }
//    var phaseError: Float16 = 0
//    func run(inputTexture: MTLTexture, outputTexture: MTLTexture, commandBuffer: MTLCommandBuffer) throws {
//        let needsUpdate: Bool
//        if let randomTexture {
//            needsUpdate = !(randomTexture.width == inputTexture.width && randomTexture.height == inputTexture.height)
//        } else {
//            needsUpdate = true
//        }
//        if needsUpdate {
//            self.randomTexture = IIRTextureFilter.texture(from: inputTexture, device: device)
//        }
//        guard let randomTexture else {
//            throw Error.cantMakeTexture
//        }
//        let randomX: UInt64 = rng.next(upperBound: 500)
//        let randomY: UInt64 = rng.next(upperBound: 500)
//        guard let randomImage = randomImageGenerator.outputImage?
//            .transformed(
//                by: CGAffineTransform(
//                    translationX: CGFloat(randomX),
//                    y: CGFloat(randomY)
//                )
//            )
//                .cropped(
//                    to: CGRect(
//                        origin: .zero,
//                        size: CGSize(
//                            width: inputTexture.width,
//                            height: inputTexture.height
//                        )
//                    )
//                ) else {
//            throw Error.cantMakeRandomImage
//        }
//        ciContext.render(
//            randomImage,
//            to: randomTexture,
//            commandBuffer: commandBuffer,
//            bounds: CGRect(
//                origin: .zero,
//                size: CGSize(
//                    width: inputTexture.width,
//                    height: inputTexture.height
//                )
//            ),
//            colorSpace: ciContext.workingColorSpace ?? CGColorSpaceCreateDeviceRGB())
//        
//        let pipelineState: MTLComputePipelineState = try pipelineCache.pipelineState(function: .chromaPhaseOffset)
//        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
//            throw Error.cantMakeComputeEncoder
//        }
//        encoder.setComputePipelineState(pipelineState)
//        encoder.setTexture(inputTexture, index: 0)
//        encoder.setTexture(randomTexture, index: 1)
//        encoder.setTexture(outputTexture, index: 2)
//        var intensity = intensity
//        encoder.setBytes(&intensity, length: MemoryLayout<Float16>.size, index: 0)
//        encoder.dispatchThreads(textureWidth: inputTexture.width, textureHeight: inputTexture.height)
//        encoder.endEncoding()
//    }
}

