//
//  NTSCEffect.swift
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-05-25.
//

import Foundation

@Observable
public class NTSCEffect {
    static let `default` = NTSCEffect()
    
    public var blackLineBorderEnabled: Bool
    public var blackLineBorderPct: Float
    public var colorBleedEnabled: Bool
    public var colorBleedBefore: Bool
    public var colorBleedXOffset: Float
    public var colorBleedYOffset: Float
    public var compositePreemphasis: Float16
    public var compositeNoiseZoom: Float
    public var compositeNoiseContrast: Float
    public var interlaceMode: InterlaceMode
    public var colorBleedOutForTV: Bool
    public var enableVHSEmulation: Bool
    public var vhsEdgeWave: Float
    public var vhsTapeSpeed: VHSSpeed
    public var vhsSharpening: Float16
    public var scanlinePhaseShift: ScanlinePhaseShift
    public var scanlinePhaseShiftOffset: Int
    public let subcarrierAmplitude: Float16 = 50
    public var vhsChromaVertBlend: Bool
    public var vhsSVideoOut: Bool
    public var outputNTSC: Bool
    public var enableHeadSwitching: Bool
    public let headSwitchingPhaseNoise: Float16 = 1.0 / 500 / 262.5
    public let headSwitchingPoint: Float16 = 1.0 - (4.5 + 0.01) / 262.5
    public let headSwitchingPhase: Float16 = (1.0 - 0.01) / 262.5
    public var headSwitchingSpeed: Float16
    
    public init(
        blackLineBorderEnabled: Bool = false,
        blackLineBorderPct: Float? = nil,
        colorBleedEnabled: Bool = true,
        colorBleedBefore: Bool = true,
        colorBleedXOffset: Float? = nil,
        colorBleedYOffset: Float? = nil,
        compositePreemphasis: Float16? = nil,
        compositeNoiseZoom: Float? = nil,
        compositeNoiseContrast: Float? = nil,
        interlaceMode: InterlaceMode? = nil,
        colorBleedOutForTV: Bool = false,
        enableVHSEmulation: Bool = true,
        vhsEdgeWave: Float? = nil,
        vhsTapeSpeed: VHSSpeed? = nil,
        vhsSharpening: Float16? = nil,
        scanlinePhaseShift: ScanlinePhaseShift? = nil,
        scanlinePhaseShiftOffset: Int? = nil,
        vhsChromaVertBlend: Bool = true,
        vhsSVideoOut: Bool = false,
        outputNTSC: Bool = true,
        enableHeadSwitching: Bool = true,
        headSwitchingSpeed: Float16? = nil
    ) {
        self.blackLineBorderEnabled = blackLineBorderEnabled
        self.blackLineBorderPct = blackLineBorderPct ?? 0.17
        self.interlaceMode = interlaceMode ?? .full
        self.colorBleedEnabled = colorBleedEnabled
        self.colorBleedBefore = colorBleedBefore
        self.colorBleedXOffset = colorBleedXOffset ?? 0
        self.colorBleedYOffset = colorBleedYOffset ?? 0
        self.compositePreemphasis = compositePreemphasis ?? 0
        self.compositeNoiseZoom = compositeNoiseZoom ?? 1
        self.compositeNoiseContrast = compositeNoiseContrast ?? 0.1
        self.colorBleedOutForTV = colorBleedOutForTV
        self.enableVHSEmulation = enableVHSEmulation
        self.vhsEdgeWave = vhsEdgeWave ?? 0
        self.vhsTapeSpeed = vhsTapeSpeed ?? .sp
        self.vhsSharpening = vhsSharpening ?? 1.5
        self.scanlinePhaseShift = scanlinePhaseShift ?? .degrees180
        self.scanlinePhaseShiftOffset = scanlinePhaseShiftOffset ?? 0
        self.vhsChromaVertBlend = vhsChromaVertBlend
        self.vhsSVideoOut = vhsSVideoOut
        self.outputNTSC = outputNTSC
        self.enableHeadSwitching = enableHeadSwitching
        self.headSwitchingSpeed = headSwitchingSpeed ?? 10
    }
}

public enum InterlaceMode: String, Identifiable, CaseIterable {
    case full
    case interlaced
    
    public var id: String {
        rawValue
    }
}

public enum VHSSpeed: String, Identifiable, CaseIterable {
    case sp
    case lp
    case ep
    
    public var id: String {
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
