//
//  PolynomialMultiply.swift
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-05-27.
//

import Foundation

func polynomialMultiply<A: Numeric>(_ a: [A], _ b: [A]) -> [A] {
    let degree: Int = a.count + b.count - 1
    var out: [A] = Array(repeating: 0, count: degree)

    for ai in 0..<a.count {
        for bi in 0..<b.count {
            out[ai + bi] += a[ai] * b[bi]
        }
    }
    return out
}
