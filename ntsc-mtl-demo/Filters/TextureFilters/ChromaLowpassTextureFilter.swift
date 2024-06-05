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
    
    private let device: MTLDevice
    private let library: MTLLibrary
    let intensity: Intensity
    let iFilter: IIRTextureFilter
    let qFilter: IIRTextureFilter
    
    init(device: MTLDevice, library: MTLLibrary, intensity: Intensity, bandwidthScale: Float, filterType: FilterType) {
        self.device = device
        self.library = library
        self.intensity = intensity
        let initialCondition: IIRTextureFilter.InitialCondition = .zero
        let rate = NTSC.rate * bandwidthScale
        switch intensity {
        case .full:
            let iFunction = Self.lowpassFilter(cutoff: 1_300_000.0, rate: rate, filterType: filterType)
            iFilter = IIRTextureFilter(device: device, library: library, numerators: iFunction.numerators, denominators: iFunction.denominators, initialCondition: initialCondition, channels: .i, scale: 1, delay: 2)
            let qFunction = Self.lowpassFilter(cutoff: 600_000.0, rate: rate, filterType: filterType)
            qFilter = IIRTextureFilter(device: device, library: library, numerators: qFunction.numerators, denominators: qFunction.denominators, initialCondition: initialCondition, channels: .q, scale: 1, delay: 4)
        case .light:
            let function = Self.lowpassFilter(cutoff: 2_600_000.0, rate: rate, filterType: filterType)
            iFilter = IIRTextureFilter(device: device, library: library, numerators: function.numerators, denominators: function.denominators, initialCondition: initialCondition, channels: .i, scale: 1, delay: 1)
            qFilter = IIRTextureFilter(device: device, library: library, numerators: function.numerators, denominators: function.denominators, initialCondition: initialCondition, channels: .q, scale: 1, delay: 1)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("Not implemented")
    }
    
    static func lowpassFilter(cutoff: Float, rate: Float, filterType: FilterType) -> IIRTransferFunction {
        switch filterType {
        case .constantK:
            let lowpass = IIRTransferFunction.lowpassFilter(cutoff: cutoff, rate: rate)
            return lowpass.cascade(n: 3)
        case .butterworth:
            return IIRTransferFunction.butterworth(cutoff: cutoff, rate: rate)
        }
    }
    
    var iTexture: MTLTexture?
    var outputITexture: MTLTexture?
    var qTexture: MTLTexture?
    var outputQTexture: MTLTexture?
    
    func run(outputTexture: MTLTexture, commandBuffer: MTLCommandBuffer) throws {
        let needsUpdate: Bool
        if let iTexture, let qTexture {
            if iTexture.width != outputTexture.width {
                needsUpdate = true
            } else if iTexture.height != outputTexture.height {
                needsUpdate = true
            } else {
                needsUpdate = false
            }
        } else {
            needsUpdate = true
        }
        
        if needsUpdate {
            let textures = Array(IIRTextureFilter.textures(width: outputTexture.width, height: outputTexture.height, pixelFormat: outputTexture.pixelFormat, device: device).prefix(4))
            self.iTexture = textures[0]
            self.qTexture = textures[1]
            self.outputITexture = textures[2]
            self.outputQTexture = textures[3]
        }
        
        guard let blitEncoder = commandBuffer.makeBlitCommandEncoder() else {
            throw Error.cantMakeBlitEncoder
        }
        
        blitEncoder.copy(from: outputTexture, to: iTexture!)
        blitEncoder.copy(from: outputTexture, to: qTexture!)
        blitEncoder.endEncoding()
        
        try iFilter.run(inputTexture: iTexture!, outputTexture: outputITexture!, commandBuffer: commandBuffer)
        try qFilter.run(inputTexture: qTexture!, outputTexture: outputQTexture!, commandBuffer: commandBuffer)
        
        let functionName = "yiqCompose3"
        guard let function = library.makeFunction(name: functionName) else {
            throw Error.cantMakeFunction(functionName)
        }
        
        let pipelineState = try device.makeComputePipelineState(function: function)
        
        guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            throw Error.cantMakeComputeEncoder
        }
        computeEncoder.setComputePipelineState(pipelineState)
        computeEncoder.setTexture(outputTexture, index: 0)
        computeEncoder.setTexture(iTexture!, index: 1)
        computeEncoder.setTexture(qTexture!, index: 2)
        
        computeEncoder.dispatchThreads(
            MTLSize(width: outputTexture.width, height: outputTexture.height, depth: 1),
            threadsPerThreadgroup: MTLSize(width: 8, height: 8, depth: 1))
        computeEncoder.endEncoding()
    }

}
