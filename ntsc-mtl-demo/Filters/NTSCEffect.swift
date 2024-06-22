//
//  NTSCEffect.swift
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-05-25.
//

import Foundation

@Observable
class NTSCEffect {
    var blackLineBorderEnabled: Bool
    var blackLineBorderPct: Float
    var interlaceMode: InterlaceMode
    var colorBleedOutForTV: Bool
    init(
        blackLineBorderEnabled: Bool = true,
        blackLineBorderPct: Float? = nil,
        interlaceMode: InterlaceMode? = nil,
        colorBleedOutForTV: Bool = false
    ) {
        self.blackLineBorderEnabled = blackLineBorderEnabled
        self.blackLineBorderPct = blackLineBorderPct ?? 0.17
        self.interlaceMode = interlaceMode ?? .full
        self.colorBleedOutForTV = colorBleedOutForTV
    }
}

enum InterlaceMode: String, Identifiable, CaseIterable {
    case full
    case interlaced
    
    var id: String {
        rawValue
    }
}
