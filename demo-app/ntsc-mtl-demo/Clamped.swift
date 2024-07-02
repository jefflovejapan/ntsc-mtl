//
//  Clamped.swift
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-05-27.
//

import Foundation

extension Numeric {
    func clamped(within range: ClosedRange<Self>) -> Self where Self: Comparable {
        if self < range.lowerBound {
            return range.lowerBound
        }
        if self > range.upperBound {
            return range.upperBound
        }
        return self
    }
}
