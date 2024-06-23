//
//  LowpassFilter.swift
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-06-22.
//

import Foundation
import Metal
import MetalPerformanceShaders

class LowpassFilter {
    let frequencyCutoff: Float
    private let blurShader: MPSImageGaussianBlur
    
    /*
     ntsc-qt uses a lowpass filter with the frequency cutoffs above for i and q
     These sigma values correspond to sampling frequency / 2 * pi * cutoff
     Applying it three (n) times in succession is equivalent to multiplying sigma by sqrt(3) (sqrt(n))
     */
    
    init(frequencyCutoff: Float, device: MTLDevice) {
        self.frequencyCutoff = frequencyCutoff
        self.blurShader = MPSImageGaussianBlur(device: device, sigma: sqrtf(3) * NTSC.rate / (2 * .pi * frequencyCutoff))
    }
    
    func run(input: MTLTexture, output: MTLTexture, commandBuffer: MTLCommandBuffer) {
        blurShader.encode(commandBuffer: commandBuffer, sourceTexture: input, destinationTexture: output)
    }
}
