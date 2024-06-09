//
//  TransferFunctionTests.swift
//  ntsc-mtl-demoTests
//
//  Created by Jeffrey Blagdon on 2024-06-07.
//

import XCTest
@testable import ntsc_mtl_demo

final class TransferFunctionTests: XCTestCase {

    func testCascadeLength() throws {
        let chromaLowpass = ChromaLowpassTextureFilter.lowpassFilter(cutoff: 1_300_000, rate: NTSC.rate * 1, filterType: .constantK)
        let gotNums = chromaLowpass.numerators
        let wantNums: [Float] = [0.0479307622, 0, 0, 0]
        XCTAssertEqual(wantNums, gotNums)
        let gotDenoms = chromaLowpass.denominators
        let wantDenoms: [Float] = [1, -1.91025209, 1.21635437, -0.258171499]
        XCTAssertEqual(wantDenoms, gotDenoms)
    }
}
