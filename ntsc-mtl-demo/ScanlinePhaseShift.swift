//
//  ChromaPhaseShift.swift
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-06-24.
//

import Foundation

enum ScanlinePhaseShift: Int, Identifiable, CaseIterable {
    case degrees0 = 0
    case degrees90 = 1
    case degrees180 = 2
    case degrees270 = 3
    
    var id: Int {
        rawValue
    }
}
