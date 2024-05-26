//
//  IIRFunction.swift
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-05-26.
//

import Foundation

struct IIRTransferFunction {
    var numerators: [Float]
    var denominators: [Float]
    
    enum Error: Swift.Error {
        case notchFrequencyOutOfBounds
    }
    
    static let lumaNotch = try! notchFilter(frequency: 0.5, quality: 2)
    static func notchFilter(frequency: Float, quality: Float) throws -> IIRTransferFunction {
        guard (0...1).contains(frequency) else {
            throw Error.notchFrequencyOutOfBounds
        }
        
        let bandwidth = (frequency / quality) * Float.pi
        let newFreq = frequency * Float.pi
        let beta = tan(bandwidth * 0.5)
        let gain = 1.0 / (1.0 + beta)
        let numerators: [Float] = [gain, -2.0 * cos(newFreq) * gain, gain]
        let denominators: [Float] = [1, -2 * cos(newFreq) * gain, (2 * gain) - 1]
        return IIRTransferFunction(numerators: numerators, denominators: denominators)
    }
}
