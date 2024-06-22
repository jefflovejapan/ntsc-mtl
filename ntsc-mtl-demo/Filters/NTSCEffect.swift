//
//  NTSCEffect.swift
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-05-25.
//

import Foundation

@Observable
class NTSCEffect {
    var interlaceMode: InterlaceMode
    var colorBleedOutForTV: Bool
    init(
        interlaceMode: InterlaceMode = .full,
        colorBleedOutForTV: Bool = false
    ) {
        self.interlaceMode = interlaceMode
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
