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

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // Any test you write for XCTest can be annotated as throws and async.
        // Mark your test throws to produce an unexpected failure when your test encounters an uncaught error.
        // Mark your test async to allow awaiting for asynchronous code to complete. Check the results with assertions afterwards.
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}
