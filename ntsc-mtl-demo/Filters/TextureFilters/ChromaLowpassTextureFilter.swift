//
//  ChromaLowpassFilter.swift
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-06-04.
//

import Foundation
import Metal

class ChromaLowpassTextureFilter {
    typealias Error = IIRTextureFilter.Error
    enum Intensity {
        case light
        case full
    }
    
    enum FiltersForIntensity {
        case full(i: IIRTextureFilter, q: IIRTextureFilter)
        case light(iAndQ: IIRTextureFilter)
    }
    
    private let device: MTLDevice
    private let pipelineCache: MetalPipelineCache
    let filters: FiltersForIntensity
    
    init(device: MTLDevice, pipelineCache: MetalPipelineCache, intensity: Intensity, bandwidthScale: Float, filterType: FilterType) {
        self.device = device
        self.pipelineCache = pipelineCache
        let initialCondition: IIRTextureFilter.InitialCondition = .zero
        let rate = NTSC.rate * bandwidthScale
        switch intensity {
        case .full:
            let iFunction = Self.lowpassFilter(cutoff: 1_300_000.0, rate: rate, filterType: filterType)
            let iFilter = IIRTextureFilter(
                device: device,
                pipelineCache: pipelineCache,
                numerators: iFunction.numerators,
                denominators: iFunction.denominators,
                initialCondition: initialCondition,
                channels: .i,
                scale: 1,
                delay: 2
            )
            let qFunction = Self.lowpassFilter(cutoff: 600_000.0, rate: rate, filterType: filterType)
            let qFilter = IIRTextureFilter(
                device: device,
                pipelineCache: pipelineCache,
                numerators: qFunction.numerators,
                denominators: qFunction.denominators,
                initialCondition: initialCondition,
                channels: .q,
                scale: 1,
                delay: 4
            )
            self.filters = .full(i: iFilter, q: qFilter)
        case .light:
            let function = Self.lowpassFilter(cutoff: 2_600_000.0, rate: rate, filterType: filterType)
            let iAndQFilter = IIRTextureFilter(
                device: device,
                pipelineCache: pipelineCache,
                numerators: function.numerators,
                denominators: function.denominators,
                initialCondition: initialCondition,
                channels: [.i, .q],
                scale: 1,
                delay: 1
            )
            self.filters = .light(iAndQ: iAndQFilter)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("Not implemented")
    }
    
    static func lowpassFilter(cutoff: Float, rate: Float, filterType: FilterType) -> IIRTransferFunction {
        switch filterType {
        case .constantK:
            let lowpass = IIRTransferFunction.lowpassFilter(cutoff: cutoff, rate: rate)
            let result = lowpass.cascade(n: 3)
            return result
        case .butterworth:
            return IIRTransferFunction.butterworth(cutoff: cutoff, rate: rate)
        }
    }
    
    var iTexture: MTLTexture?
    var qTexture: MTLTexture?
    private var yiqCompose3PipelineState: MTLComputePipelineState?
    private var yiqComposePipelineState: MTLComputePipelineState?
    
    var pipelineState: MTLComputePipelineState {
        get throws {
            switch filters {
            case .light:
                return try pipelineCache.pipelineState(function: .yiqCompose)
            case .full:
                return try pipelineCache.pipelineState(function: .yiqCompose3)
            }
        }
    }
    
    func run(inputTexture: MTLTexture, outputTexture: MTLTexture, commandBuffer: MTLCommandBuffer) throws {
        let needsUpdate: Bool
        if let iTexture {
            if iTexture.width != inputTexture.width {
                needsUpdate = true
            } else if iTexture.height != inputTexture.height {
                needsUpdate = true
            } else {
                needsUpdate = false
            }
        } else {
            needsUpdate = true
        }
        
        if needsUpdate {
            let textures = Array(IIRTextureFilter.textures(width: inputTexture.width, height: inputTexture.height, pixelFormat: inputTexture.pixelFormat, device: device).prefix(2))
            self.iTexture = textures[0]
            self.qTexture = textures[1]
        }
        
        switch filters {
        case let .light(iAndQFilter):
            try iAndQFilter.run(inputTexture: inputTexture, outputTexture: iTexture!, commandBuffer: commandBuffer)
            
        case let .full(iFilter, qFilter):
            try iFilter.run(inputTexture: inputTexture, outputTexture: iTexture!, commandBuffer: commandBuffer)
            try qFilter.run(inputTexture: inputTexture, outputTexture: qTexture!, commandBuffer: commandBuffer)
        }
        
        let pipelineState = try self.pipelineState
        guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            throw Error.cantMakeComputeEncoder
        }
        
        computeEncoder.setComputePipelineState(pipelineState)
        switch filters {
        case .light:
            computeEncoder.setTexture(inputTexture, index: 0)
            computeEncoder.setTexture(iTexture!, index: 1)
            computeEncoder.setTexture(outputTexture, index: 2)
            let channels: YIQChannels = [.i, .q]
            var channelMix = channels.floatMix
            computeEncoder.setBytes(&channelMix, length: MemoryLayout<Float16>.size * 4, index: 0)
        case .full:
            computeEncoder.setTexture(inputTexture, index: 0)
            computeEncoder.setTexture(iTexture!, index: 1)
            computeEncoder.setTexture(qTexture!, index: 2)
            computeEncoder.setTexture(outputTexture, index: 3)
        }
        
        computeEncoder.dispatchThreads(textureWidth: inputTexture.width, textureHeight: inputTexture.height)
        computeEncoder.endEncoding()
    }

}
