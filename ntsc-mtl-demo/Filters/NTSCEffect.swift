//
//  NTSCEffect.swift
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-05-25.
//

import Foundation

struct NTSCEffect {
    var randomSeed: Int
    var useField: UseField
    var filterType: FilterType
    var inputLumaFilter: LumaLowpass
    var chromaLowpassIn: ChromaLowpass
    var chromaDemodulation: ChromaDemodulationFilter
    var lumaSmear: Float
    var compositePreemphasis: Float16
    var videoScanlinePhaseShift: PhaseShift
    var videoScanlinePhaseShiftOffset: Int
    
    var headSwitching: HeadSwitchingSettings?
    var trackingNoise: TrackingNoiseSettings?
    var compositeNoise: FBMNoiseSettings?
    var ringing: RingingSettings?
    var lumaNoise: FBMNoiseSettings?
    var chromaNoise: FBMNoiseSettings?
    
    var snowIntensity: Float
    var snowAnisotropy: Float
    var chromaPhaseNoiseIntensity: Float
    var chromaPhaseError: Float
    var chromaDelay: (Float, Int)
    var vhsSettings: VHSSettings
    var chromaVertBlend: Bool
    var chromaLowpassOut: ChromaLowpass
    var bandwidthScale: Float
}

enum ChromaDemodulationFilter: Int {
    case box
    case notch
    case oneLineComb
    case twoLineComb
}

enum UseField: Int {
    case alternating = 0
    case upper
    case lower
    case both
    case interleavedUpper
    case interleavedLower
}

enum FilterType: Int {
    case constantK
    case butterworth
}

enum LumaLowpass {
    case none
    case box
    case notch
}

enum ChromaLowpass {
    case none
    case light
    case full
}

enum PhaseShift: UInt {
    case degrees0 = 0
    case degrees90
    case degrees180
    case degrees270
}

struct HeadSwitchingSettings {
    var height: UInt
    var offset: UInt
    var horizShift: Float
    var midLine: HeadSwitchingMidLineSettings?
}

struct HeadSwitchingMidLineSettings {
    var position: Float
    var jitter: Float
}

struct TrackingNoiseSettings {
    var height: UInt
    var waveIntensity: Float
    var snowIntensity: Float
    var snowAnisotropy: Float
    var noiseIntensity: Float
}

struct FBMNoiseSettings {
    var frequency: Float
    var intensity: Float16
    var detail: UInt
}

struct RingingSettings {
    var frequency: Float
    var power: Float
    var intensity: Float16
}

struct VHSSettings {
    var tapeSpeed: VHSTapeSpeed?
    var chromaLoss: Float
    var sharpen: VHSSharpenSettings?
    var edgeWave: VHSEdgeWaveSettings?
}

enum VHSTapeSpeed: Int {
    case sp = 1
    case lp
    case ep
}

struct VHSSharpenSettings {
    var intensity: Float
    var frequency: Float
}

struct VHSEdgeWaveSettings {
    var intensity: Float
    var speed: Float
    var frequency: Float
    var detail: Int
}
