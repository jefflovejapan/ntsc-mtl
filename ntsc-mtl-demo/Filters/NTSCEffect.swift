//
//  NTSCEffect.swift
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-05-25.
//

import Foundation

@Observable
class NTSCEffect {
    static let `default` = NTSCEffect()
    
    var blackLineBorderEnabled: Bool
    var blackLineBorderPct: Float
    var colorBleedEnabled: Bool
    var colorBleedBefore: Bool
    var colorBleedXOffset: Float
    var colorBleedYOffset: Float
    var interlaceMode: InterlaceMode
    var colorBleedOutForTV: Bool
    init(
        blackLineBorderEnabled: Bool = false,
        blackLineBorderPct: Float? = nil,
        colorBleedEnabled: Bool = true,
        colorBleedBefore: Bool = true,
        colorBleedXOffset: Float? = nil,
        colorBleedYOffset: Float? = nil,
        interlaceMode: InterlaceMode? = nil,
        colorBleedOutForTV: Bool = false
    ) {
        self.blackLineBorderEnabled = blackLineBorderEnabled
        self.blackLineBorderPct = blackLineBorderPct ?? 0.17
        self.interlaceMode = interlaceMode ?? .full
        self.colorBleedEnabled = colorBleedEnabled
        self.colorBleedBefore = colorBleedBefore
        self.colorBleedXOffset = colorBleedXOffset ?? 0
        self.colorBleedYOffset = colorBleedYOffset ?? 0
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
