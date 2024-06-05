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
    
    func testChromaLowpassScalarFullButterworthI() throws {
        let r: Float = Float(20) / Float(255)
        let g: Float = Float(230) / Float(255)
        let b: Float = Float(20) / Float(255)
        
        let yiq = toYIQ(rgba: SIMD4<Float>.init(r, g, b, 1))
        
        let bandwidthScale = NTSCEffect.default.bandwidthScale
        
        let iFunction = ChromaLowpassFilter.lowpassFilter(cutoff: 1_300_000.0, rate: NTSC.rate * bandwidthScale, filterType: .butterworth)
        let initialCondition: IIRTester.InitialCondition = .zero
        let scale: Float = 1
        let delay: UInt = 2
        let floatTester: IIRTester = IIRTester(numerators: iFunction.numerators, denominators: iFunction.denominators, initialCondition: initialCondition, scale: scale, delay: delay)
        let gotI = try floatTester.value(for: yiq[1]) // y[i]q
        
        let gotYIQA = SIMD4<Float>.init(yiq[0], gotI, yiq[2], 1)
        let gotRGB = toRGB(yiqa: gotYIQA)
        let gotRGBInt = SIMD4<Int>.init(gotRGB * 255, rounding: .toNearestOrAwayFromZero)
        XCTAssertEqual(gotRGBInt, SIMD4<Int>(x: 72, y: 215, z: 0, w: 255))
    }
    
    func testNegativeRGBIsEquivalent() {
        let rgbWithZero = SIMD4<Float>(72, 215, 0, 255) / 255
        let yiqWithZero = toYIQ(rgba: rgbWithZero)
        let rgbWithNegative = SIMD4<Float>(72, 215, -40, 255) / 255
        let yiqWithNegative = toYIQ(rgba: rgbWithNegative)
        XCTAssertEqual(yiqWithZero, yiqWithNegative)
    }
    
    func testChromaLowpassScalarFullButterworthQ() throws {
        let r: Float = 0.5
        let g: Float = 0.5
        let b: Float = 0.5
        
        let yiq = toYIQ(rgba: SIMD4<Float>.init(r, g, b, 1))
        
        let bandwidthScale = NTSCEffect.default.bandwidthScale
        
        let iFunction = ChromaLowpassFilter.lowpassFilter(cutoff: 600_000.0, rate: NTSC.rate * bandwidthScale, filterType: .butterworth)
        let initialCondition: IIRTester.InitialCondition = .zero
        let scale: Float = 1
        let delay: UInt = 4
        let floatTester: IIRTester = IIRTester(numerators: iFunction.numerators, denominators: iFunction.denominators, initialCondition: initialCondition, scale: scale, delay: delay)
        let got = try floatTester.value(for: yiq.z) // yi[q]
        let want: Float = 0.0
        XCTAssertEqual(want, got)
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}
