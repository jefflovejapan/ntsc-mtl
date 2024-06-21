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
    init(
        interlaceMode: InterlaceMode = .full
    ) {
        self.interlaceMode = interlaceMode
    }
}

enum InterlaceMode: String, Identifiable, CaseIterable {
    case full
    case interlaced
    
    var id: String {
        rawValue
    }
}
