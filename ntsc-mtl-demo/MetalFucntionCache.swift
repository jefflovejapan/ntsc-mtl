//
//  MetalFucntionCache.swift
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-06-08.
//

import Foundation
import Metal

enum KernelFunction: String, CaseIterable {
    case convertToYIQ
    case convertToRGB
    case chromaIntoLuma
    case snowIntensity
    case snow
    case geometricDistribution
    case yiqCompose
    case multiplyLuma
    case yiqCompose3
    case iirInitialCondition
    case paint
    case iirFilterSample
    case iirSideEffect
    case iirMultiply
    case iirFinalImage
    case shiftRow
    case shiftRowMidline
    case chromaPhaseOffset
    case chromaPhaseNoise
    case chromaDelay
    case interleave
    case edgeWave
//    case noise
//    case blend
}

class MetalPipelineCache {
    enum Error: Swift.Error {
        case cantMakeFunction(KernelFunction)
        case underlying(Swift.Error)
        case noPipelineStateAvailable
    }
    let device: MTLDevice
    let library: MTLLibrary
    
    init(device: MTLDevice, library: MTLLibrary) throws {
        self.device = device
        self.library = library
        // Warm cache
        for function in KernelFunction.allCases {
            _ = try pipelineState(function: function)
        }
    }
    
    var pipelineStateByFunction: [KernelFunction: MTLComputePipelineState] = [:]
    
    func pipelineState(function: KernelFunction) throws -> MTLComputePipelineState {
        if let pipelineState = pipelineStateByFunction[function] {
            return pipelineState
        }
        guard let fn = library.makeFunction(name: function.rawValue) else {
            throw Error.cantMakeFunction(function)
        }
        do {
            let pipelineState = try device.makeComputePipelineState(function: fn)
            self.pipelineStateByFunction[function] = pipelineState
            return pipelineState
        } catch {
            throw Error.underlying(error)
        }
    }
}
