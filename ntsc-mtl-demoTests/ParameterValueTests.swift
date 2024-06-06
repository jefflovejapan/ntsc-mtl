//
//  ParameterValueTests.swift
//  ntsc-mtl-demoTests
//
//  Created by Jeffrey Blagdon on 2024-06-06.
//

import XCTest
@testable import ntsc_mtl_demo

final class ParameterValueTests: XCTestCase {
    
    private func testParameterValues(_ iirTransferFunction: IIRTransferFunction, line: UInt = #line)  {
        for idx in iirTransferFunction.numerators.indices {
            let num = iirTransferFunction.numerators[idx]
            XCTAssert(Float.float16Range.contains(num), "Numerator at idx \(idx) outside float16Range: \(num)", line: line)
        }
        for idx in iirTransferFunction.denominators.indices {
            let denom = iirTransferFunction.denominators[idx]
            XCTAssert(Float.float16Range.contains(denom), "Denominator at idx \(idx) outside float16Range: \(denom)", line: line)
        }
    }

    func testNotchFilter() throws {
        let notch = try IIRTransferFunction.notchFilter(frequency: 0.5, quality: 2)
        testParameterValues(notch)
    }
}
