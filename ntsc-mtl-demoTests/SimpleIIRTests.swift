//
//  SimpleIIRTests.swift
//  ntsc-mtl-demoTests
//
//  Created by Jeffrey Blagdon on 2024-06-03.
//

import XCTest
@testable import ntsc_mtl_demo

final class SimpleIIRTests: XCTestCase {
    func testConversionToYIQ() throws {
        let r: Float = 0.5
        let g: Float = 0.5
        let b: Float = 0.5
        let yiq = toYIQ(rgba: SIMD4<Float>(r, g, b, 1))
        
        let wantY: Float = 0.5
        let wantI: Float = 0
        let wantQ: Float = -1.4901161e-8
        XCTAssertEqual(wantY, yiq.x)
        XCTAssertEqual(wantI, yiq.y)
        XCTAssertEqual(wantQ, yiq.z)
    }
    
    func testConversionFromYIQ() throws {
        let y: Float = 0.5
        let i: Float = 0.5
        let q: Float = 0.5
        let yiq = toRGB(yiqa: SIMD4<Float>(y, i, q, 1))
        
        let wantR: Float = 1.2875
        let wantG: Float = 0.040499985
        let wantB: Float = 0.7985
        XCTAssertEqual(wantR, yiq.x)
        XCTAssertEqual(wantG, yiq.y)
        XCTAssertEqual(wantB, yiq.z)
    }
    
    func testChromaLowpassScalarFullButterworth() throws {
        let r: Float = 0.5
        let g: Float = 0.5
        let b: Float = 0.5
        
        let yiq = toYIQ(rgba: SIMD4<Float>.init(r, g, b, 1))
        
        let bandwidthScale = NTSCEffect.default.bandwidthScale
        let iFunction = ChromaLowpassFilter.lowpassFilter(cutoff: 1_300_000.0, rate: NTSC.rate * bandwidthScale, filterType: .butterworth)
        let initialCondition: IIRTester.InitialCondition = .zero
        let scale: Float = 1
        let delay: UInt = 2
        let floatTester: IIRTester = IIRTester(numerators: iFunction.numerators, denominators: iFunction.denominators, initialCondition: initialCondition, scale: scale, delay: delay)
        let got = try floatTester.value(for: yiq.y) // i
        let want: Float = -0.112611488
        XCTAssertEqual(want, got)
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}
