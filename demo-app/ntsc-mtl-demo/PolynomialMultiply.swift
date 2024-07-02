//
//  PolynomialMultiply.swift
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-05-27.
//

import Foundation

var polyMulCount: UInt = 0
func polynomialMultiply<A: Numeric>(_ a: [A], _ b: [A]) -> [A] {
//    print("poly_mul_count: \(polyMulCount)")
//    print("a in: \(a)")
//    print("b in: \(b)")
    let degree: Int = a.count + b.count - 1
//    print("degree: \(degree)")
    var out: [A] = Array(repeating: 0, count: degree)

    for ai in 0..<a.count {
        for bi in 0..<b.count {
//            print("ai: \(ai)")
//            print("a[ai]: \(a[ai])")
//            print("bi: \(bi)")
//            print("b[bi]: \(b[bi])")
            out[ai + bi] += (a[ai] * b[bi])
        }
    }
//    print("out: \(out)");
    polyMulCount += 1
    return out
}
