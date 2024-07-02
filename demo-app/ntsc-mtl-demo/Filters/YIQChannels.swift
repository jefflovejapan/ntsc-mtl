//
//  YIQChannels.swift
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-05-31.
//

import Foundation
import CoreImage

struct YIQChannels: OptionSet {
    let rawValue: Int
    static let y = YIQChannels(rawValue: 1 << 0) // 1 << 0 = 1 (Binary 0001)
    static let i = YIQChannels(rawValue: 1 << 1) // 1 << 1 = 2 (Binary 0010)
    static let q = YIQChannels(rawValue: 1 << 2) // 1 << 2 = 4 (Binary 0100)
    static let a = YIQChannels(rawValue: 1 << 3) // 1 << 3 = 8 (Binary 1000)

    static let all: YIQChannels = [.y, .i, .q, .a]
    static let yiq: YIQChannels = [.y, .i, .q]
    
    var floatMix: [Float16] {
        let y: Float16 = self.contains(.y) ? 1 : 0
        let i: Float16 = self.contains(.i) ? 1 : 0
        let q: Float16 = self.contains(.q) ? 1 : 0
        let a: Float16 = self.contains(.a) ? 1 : 0
        return [y, i, q, a]
    }
}
