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
    case blackLineBorder
    case colorBleed
    case paint
    case lowpass
    case interleave
    case convertToRGB
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
