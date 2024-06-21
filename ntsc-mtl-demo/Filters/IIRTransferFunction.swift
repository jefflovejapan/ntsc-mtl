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
    
    init(numerators: [Float], denominators: [Float]) {
        let maxLength = max(numerators.count, denominators.count)
        self.numerators = numerators.padded(toLength: maxLength, with: 0)
        self.denominators = denominators.padded(toLength: maxLength, with: 0)
    }
    
    enum Error: Swift.Error {
        case notchFrequencyOutOfBounds
    }
    
    static let lumaNotch = try! notchFilter(frequency: 0.5, quality: 2)
    
    static func notchFilter(frequency: Float, quality: Float) throws -> IIRTransferFunction {
        guard (0...1).contains(frequency) else {
            throw Error.notchFrequencyOutOfBounds
        }
        
        let normalizedBandwidth = (frequency / quality) * .pi
        let normalizedFrequency = frequency * .pi
        let gb: Float = 1 / (sqrt(2))
        let beta: Float = (sqrt(1 - (pow(gb, 2)))/gb) * tan(normalizedBandwidth / 2)
        let gain = 1.0 / (1.0 + beta)
        let middleParam = -2.0 * cos(normalizedFrequency) * gain
        let numerators: [Float] = [gain, middleParam, gain]
        let denominators: [Float] = [1, middleParam, (2 * gain) - 1]
        return IIRTransferFunction(numerators: numerators, denominators: denominators)
    }
    
    static func compositePreemphasis(bandwidthScale: Float) -> IIRTransferFunction {
        let cutoff: Float = (315000000.0 / 88.0 / 2.0) * bandwidthScale
        let rate = NTSC.rate * bandwidthScale
        return lowpassFilter(cutoff: cutoff, rate: rate)
    }
    
    static func lumaSmear(amount: Float, bandwidthScale: Float) -> IIRTransferFunction {
        return lowpassFilter(cutoff: exp2(-4 * amount) * 0.25, rate: bandwidthScale)
    }
        
    static func lowpassFilter(cutoff: Float, rate: Float) -> IIRTransferFunction {
        let timeInterval = 1.0 / rate
        let tau = 1.0 / (cutoff * 2.0 * .pi)
        let alpha = timeInterval / (tau + timeInterval)
        
        let numerators: [Float] = [alpha]
        let denominators: [Float] = [1, -(1 - alpha)]
        return IIRTransferFunction(
            numerators: numerators,
            denominators: denominators
        )
    }
    
    static func butterworth(cutoff: Float, rate: Float) -> IIRTransferFunction {
        /*
         let coeffs = biquad::Coefficients::<f32>::from_params(
                 biquad::Type::LowPass,
                 biquad::Hertz::<f32>::from_hz(rate).unwrap(),
                 biquad::Hertz::<f32>::from_hz(cutoff.min(rate * 0.5)).unwrap(),
                 biquad::Q_BUTTERWORTH_F32, // constant
             )
             .unwrap();
         
         pub fn from_params(
             filter: Type<f32>, (lowpass)
             fs: Hertz<f32>, (from_hz(rate))
             f0: Hertz<f32>, (from_hz(cutoff.min(rate * 0.5))
             q_value: f32,
         ) -> Result<Coefficients<f32>, Errors> {
             if 2.0 * f0.hz() > fs.hz() {
                 return Err(Errors::OutsideNyquist);
             }

             if q_value < 0.0 {
                 return Err(Errors::NegativeQ);
             }

             let omega = 2.0 * core::f32::consts::PI * f0.hz() / fs.hz();

                 Type::LowPass => {
                     // The code for omega_s/c and alpha is currently duplicated due to the single pole
                     // low pass filter not needing it and when creating coefficients are commonly
                     // assumed to be of low computational complexity.
                     let omega_s = omega.sin();
                     let omega_c = omega.cos();
                     let alpha = omega_s / (2.0 * q_value);

                     let b0 = (1.0 - omega_c) * 0.5;
                     let b1 = 1.0 - omega_c;
                     let b2 = (1.0 - omega_c) * 0.5;
                     let a0 = 1.0 + alpha;
                     let a1 = -2.0 * omega_c;
                     let a2 = 1.0 - alpha;

                     Ok(Coefficients {
                         a1: a1 / a0,
                         a2: a2 / a0,
                         b0: b0 / a0,
                         b1: b1 / a0,
                         b2: b2 / a0,
                     })
                 }
             }
         }
     }

         */
        
        let newCutoff = min(cutoff, rate * 0.5)
        
        // Calculate normalized frequency
        let omega = 2.0 * .pi * newCutoff / rate
        let cosOmega = cos(omega)
        let sinOmega = sin(omega)
        let q: Float = sqrt(2) / 2
        let alpha = (sinOmega / (2.0 * q))
        
        // Butterworth filter (Q factor is sqrt(2)/2 for a Butterworth filter)
        let b0 = (1.0 - cosOmega) * 0.5
        let b1 = 1.0 - cosOmega
        let b2 = (1.0 - cosOmega) * 0.5
        let a0 = 1.0 + alpha
        let a1 = -2.0 * cosOmega
        let a2 = 1.0 - alpha
        
        // Normalize coefficients
        let nums = [b0 / a0, b1 / a0, b2 / a0]
        let denoms = [1.0, a1 / a0, a2 / a0]
        
        return IIRTransferFunction(numerators: nums, denominators: denoms)
    }
}

private func trimZeroes<A: Comparable & SignedNumeric>(_ a: [A]) -> [A] {
    var idx = a.count - 1
    while abs(a[idx]) == .zero {
        idx -= 1
    }
    return Array(a[0...idx])
}

extension IIRTransferFunction {
    static func *(lhs: IIRTransferFunction, rhs: IIRTransferFunction) -> IIRTransferFunction {
        let lNums = trimZeroes(lhs.numerators)
        let rNums = trimZeroes(rhs.numerators)
        let nums = polynomialMultiply(lNums, rNums)
        let lDenoms = trimZeroes(lhs.denominators)
        let rDenoms = trimZeroes(rhs.denominators)
        let denoms = polynomialMultiply(lDenoms, rDenoms)
        return IIRTransferFunction(numerators: nums, denominators: denoms)
    }
    
    func cascade(n: UInt) -> IIRTransferFunction {
        var fn = self
        for _ in 1..<n {
            let result = (fn * fn)
            fn = result
        }
        return fn
    }
}
