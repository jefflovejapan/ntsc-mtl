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
    var enableVHSEmulation: Bool
    var vhsEdgeWave: Float
    var vhsTapeSpeed: VHSSpeed
    var vhsSharpening: Float16
    var scanlinePhaseShift: ScanlinePhaseShift
    var scanlinePhaseShiftOffset: Int
    let subcarrierAmplitude: Float16 = 50
    var vhsCompositeVideoOut: Bool
    
    init(
        blackLineBorderEnabled: Bool = false,
        blackLineBorderPct: Float? = nil,
        colorBleedEnabled: Bool = true,
        colorBleedBefore: Bool = true,
        colorBleedXOffset: Float? = nil,
        colorBleedYOffset: Float? = nil,
        interlaceMode: InterlaceMode? = nil,
        colorBleedOutForTV: Bool = false,
        enableVHSEmulation: Bool = true,
        vhsEdgeWave: Float? = nil,
        vhsTapeSpeed: VHSSpeed? = nil,
        vhsSharpening: Float16? = nil,
        scanlinePhaseShift: ScanlinePhaseShift? = nil,
        scanlinePhaseShiftOffset: Int? = nil,
        vhsCompositeVideoOut: Bool = false
    ) {
        self.blackLineBorderEnabled = blackLineBorderEnabled
        self.blackLineBorderPct = blackLineBorderPct ?? 0.17
        self.interlaceMode = interlaceMode ?? .full
        self.colorBleedEnabled = colorBleedEnabled
        self.colorBleedBefore = colorBleedBefore
        self.colorBleedXOffset = colorBleedXOffset ?? 0
        self.colorBleedYOffset = colorBleedYOffset ?? 0
        self.colorBleedOutForTV = colorBleedOutForTV
        self.enableVHSEmulation = enableVHSEmulation
        self.vhsEdgeWave = vhsEdgeWave ?? 0
        self.vhsTapeSpeed = vhsTapeSpeed ?? .sp
        self.vhsSharpening = vhsSharpening ?? 1.5
        self.scanlinePhaseShift = scanlinePhaseShift ?? .degrees180
        self.scanlinePhaseShiftOffset = scanlinePhaseShiftOffset ?? 0
        self.vhsCompositeVideoOut = vhsCompositeVideoOut
    }
}

enum InterlaceMode: String, Identifiable, CaseIterable {
    case full
    case interlaced
    
    var id: String {
        rawValue
    }
}

enum VHSSpeed: String, Identifiable, CaseIterable {
    case sp
    case lp
    case ep
    
    var id: String {
        rawValue
    }
    
    var lumaCut: Float {
        switch self {
        case .sp:
            2_400_000
        case .lp:
            1_900_000
        case .ep:
            1_400_000
        }
    }
    var chromaCut: Float {
        switch self {
        case .sp:
            320_000
        case .lp:
            300_000
        case .ep:
            280_000
        }
    }
    
    var chromaDelay: UInt {
        switch self {
        case .sp:
            9
        case .lp:
            12
        case .ep:
            14
        }
    }
}
