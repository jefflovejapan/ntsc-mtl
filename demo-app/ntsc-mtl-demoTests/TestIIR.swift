//
//  TestIIR.swift
//  ntsc-mtl-demoTests
//
//  Created by Jeffrey Blagdon on 2024-06-03.
//

import Foundation
@testable import ntsc_mtl_demo
import CoreImage

protocol LinearlyCombinable {
    static var zero: Self { get }
}

extension Float: LinearlyCombinable {
    
}

class IIRTester {
    enum InitialCondition {
        case zero
        case firstSample
        case constant(Float)
    }
    
    typealias Element = Float
    let numerators: [Float]
    let denominators: [Float]
    let scale: Float
    let delay: UInt
    let initialCondition: InitialCondition
    var z: [Element] = []
    
    init(numerators: [Float], denominators: [Float], initialCondition: InitialCondition, scale: Float, delay: UInt) {
        let maxLength = max(numerators.count, denominators.count)
        let paddedNumerators = numerators.padded(toLength: maxLength, with: 0)
        let paddedDenominators = denominators.padded(toLength: maxLength, with: 0)
        self.initialCondition = initialCondition
        self.numerators = paddedNumerators
        self.denominators = paddedDenominators
        self.scale = scale
        self.delay = delay
    }
    
    enum Error: Swift.Error {
        case noNonZeroDenominators
        case noZ
        case noNumerators
    }
    
    private func initialize(with value: Element, initialCondition: InitialCondition) throws {
        let val: Element
        switch initialCondition {
        case .zero:
            val = .zero
            for idx in z.indices {
                z[idx] = val
            }
            return
        case .firstSample:
            val = value
        case .constant(let a):
            val = a
        }
        
        guard let firstNonZeroCoeff = denominators.first(where: { !$0.isZero }) else {
            throw Error.noNonZeroDenominators
        }
        let normalizedNumerators = numerators.map { num in
            num / firstNonZeroCoeff
        }
        let normalizedDenominators = denominators.map { den in
            den / firstNonZeroCoeff
        }
        var bSum: Float = 0
        for i in 1 ..< numerators.count {
            let num = normalizedNumerators[i]
            let den = normalizedDenominators[i]
            bSum += num - (den * normalizedNumerators[0])
        }
        let z0 = bSum / normalizedDenominators.reduce(.zero, +)
        z[0] = z0
        var aSum: Float = 1
        var cSum: Float = 0
        for i in 1 ..< numerators.count {
            let num = normalizedNumerators[i]
            let den = normalizedDenominators[i]
            aSum += den
            cSum += (num - (den * normalizedNumerators[0]))
            let zImage = Self.applyInitialCondition(input: value, z0: z0, aSum: aSum, cSum: cSum)
            z[i] = zImage
        }
        z[0] *= value
    }
    
    private static func applyInitialCondition(input: Float, z0: Float, aSum: Float, cSum: Float) -> Float {
        return ((aSum * z0) - cSum) * input
    }
    
    func value(for sample: Element) throws -> Element {
        if z.isEmpty {
            self.z = Array.init(repeating: .zero, count: numerators.count)
            try! self.initialize(with: sample, initialCondition: initialCondition)
        }
        
        guard let z0 = z.first else {
            throw Error.noZ
        }
        
        guard let num = numerators.first else {
            throw Error.noZ
        }
        
        let filteredSample = z0 + (num * sample)
        
        for i in numerators.indices {
            let nextIdx = i+1
            guard nextIdx < numerators.count else {
                break
            }
            let sideEffectedPlusOne = z[nextIdx]
            z[i] = sideEffectedPlusOne + (numerators[nextIdx] * sample) - (denominators[nextIdx] * filteredSample)
        }
        return ((filteredSample - sample) * scale) + sample
    }
}
