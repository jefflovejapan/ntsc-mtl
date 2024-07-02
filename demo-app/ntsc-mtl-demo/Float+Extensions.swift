//
//  Float+Extensions.swift
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-06-06.
//

import Foundation

extension Float {
    static let float16Min: Self = pow(2, -14)
    static let float16Max: Self = (2 - pow(2, -10)) * pow(2, 15)
    static let float16Range = float16Min ... float16Max
}
