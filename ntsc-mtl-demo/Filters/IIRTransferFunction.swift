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
    
//    def _design_notch_peak_filter(w0, Q, ftype, fs=2.0):
//        """
//        Design notch or peak digital filter.
//
//        Parameters
//        ----------
//        w0 : float
//            Normalized frequency to remove from a signal. If `fs` is specified,
//            this is in the same units as `fs`. By default, it is a normalized
//            scalar that must satisfy  ``0 < w0 < 1``, with ``w0 = 1``
//            corresponding to half of the sampling frequency.
//        Q : float
//            Quality factor. Dimensionless parameter that characterizes
//            notch filter -3 dB bandwidth ``bw`` relative to its center
//            frequency, ``Q = w0/bw``.
//        ftype : str
//            The type of IIR filter to design:
//
//                - notch filter : ``notch``
//                - peak filter  : ``peak``
//        fs : float, optional
//            The sampling frequency of the digital system.
//
//            .. versionadded:: 1.2.0:
//
//        Returns
//        -------
//        b, a : ndarray, ndarray
//            Numerator (``b``) and denominator (``a``) polynomials
//            of the IIR filter.
//        """
//
//        # Guarantee that the inputs are floats
//        w0 = float(w0)
//        Q = float(Q)
//        w0 = 2*w0/fs
//
//        # Checks if w0 is within the range
//        if w0 > 1.0 or w0 < 0.0:
//            raise ValueError("w0 should be such that 0 < w0 < 1")
//
//        # Get bandwidth
//        bw = w0/Q ✅
//
//        # Normalize inputs
//        bw = bw*np.pi ✅
//        w0 = w0*np.pi ✅
//
//        # Compute -3dB attenuation
//        gb = 1/np.sqrt(2) ✅
//
//        if ftype == "notch":
//            # Compute beta: formula 11.3.4 (p.575) from reference [1]
//            beta = (np.sqrt(1.0-gb**2.0)/gb)*np.tan(bw/2.0)
//        elif ftype == "peak":
//            # Compute beta: formula 11.3.19 (p.579) from reference [1]
//            beta = (gb/np.sqrt(1.0-gb**2.0))*np.tan(bw/2.0)
//        else:
//            raise ValueError("Unknown ftype.")
//
//        # Compute gain: formula 11.3.6 (p.575) from reference [1]
//        gain = 1.0/(1.0+beta)
//
//        # Compute numerator b and denominator a
//        # formulas 11.3.7 (p.575) and 11.3.21 (p.579)
//        # from reference [1]
//        b = gain*np.array([1.0, -2.0*np.cos(w0), 1.0]) //
//        a = np.array([1.0, -2.0*gain*np.cos(w0), (2.0*gain-1.0)])
//
//        return b, a

    
    static func notchFilter(frequency: Float, quality: Float) throws -> IIRTransferFunction {
        guard (0...1).contains(frequency) else {
            throw Error.notchFrequencyOutOfBounds
        }
        
        let normalizedBandwidth = (frequency / quality) * .pi
        let normalizedFrequency = frequency * .pi
        let gb: Float = 1 / (sqrt(2))
        
        
        let beta = (sqrt(1 - (pow(gb, 2)))/gb) * tan(normalizedBandwidth / 2)
        let gain = 1.0 / (1.0 + beta)
        let middleParam = -2.0 * cos(normalizedFrequency) * gain
        //     let num = vec![gain, -2.0 * freq.cos() * gain, gain];
        let numerators: [Float] = [gain, middleParam, gain]
//        let den = vec![1.0, -2.0 * freq.cos() * gain, 2.0 * gain - 1.0];
        let denominators: [Float] = [1, middleParam, (2 * gain) - 1]
        return IIRTransferFunction(numerators: numerators, denominators: denominators)
    }
    
    static func hardCodedLumaNotch() -> IIRTransferFunction {
        return IIRTransferFunction(numerators: [0.70710677, 6.181724e-08, 0.70710677, 0.0], denominators: [1.0, 6.181724e-8, 0.41421354, 0.0])
    }
    
    static func compositePreemphasis(bandwidthScale: Float) -> IIRTransferFunction {
        let cutoff: Float = (315000000.0 / 88.0 / 2.0) * bandwidthScale
        let rate = NTSC.rate * bandwidthScale
        return lowpassFilter(cutoff: cutoff, rate: rate)
    }
    
    /*
    if self.composite_preemphasis != 0.0 {
        let preemphasis_filter = make_lowpass(
            (315000000.0 / 88.0 / 2.0) * self.bandwidth_scale,
            NTSC_RATE * self.bandwidth_scale,
        );
        filter_plane(
            yiq.y,
            width,
            &preemphasis_filter,
            InitialCondition::Zero,
            -self.composite_preemphasis,
            0,
        );
    }
     */
    
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
        let newCutoff = min(cutoff, rate * 0.5)
        
        // Calculate normalized frequency
        let omega = 2.0 * .pi * newCutoff / rate
        let cosOmega = cos(omega)
        let sinOmega = sin(omega)
        let alpha = sinOmega / 2.0
        
        // Butterworth filter (Q factor is sqrt(2)/2 for a Butterworth filter)
        let a0 = 1.0 + alpha
        let a1 = -2.0 * cosOmega
        let a2 = 1.0 - alpha
        let b0 = (1.0 - cosOmega) / 2.0
        let b1 = 1.0 - cosOmega
        let b2 = (1.0 - cosOmega) / 2.0
        
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
        for _ in 0..<n {
            fn = fn * fn
        }
        return fn
    }
}
