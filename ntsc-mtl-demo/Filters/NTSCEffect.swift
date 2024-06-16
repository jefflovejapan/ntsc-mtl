//
//  NTSCEffect.swift
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-05-25.
//

import Foundation

@Observable
class NTSCEffect {
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
    var headSwitchingEnabled: Bool
    var headSwitching: HeadSwitchingSettings
    var trackingNoise: TrackingNoiseSettings?
    var compositeNoise: FBMNoiseSettings?
    var ringingEnabled: Bool
    var ringing: RingingSettings
    var lumaNoise: FBMNoiseSettings?
    var chromaNoise: FBMNoiseSettings?
    var snowIntensity: Float
    var snowAnisotropy: Float
    var chromaPhaseNoiseIntensity: Float16
    var chromaPhaseError: Float16
    var chromaDelay: (Float16, Int)
    var isVHSEnabled: Bool
    var vhsSettings: VHSSettings
    var chromaVertBlend: Bool
    var chromaLowpassOut: ChromaLowpass
    var bandwidthScale: Float
    
    init(
        randomSeed: Int = 0,
        useField: UseField = UseField.interleavedUpper,
        filterType: FilterType = FilterType.constantK,
        inputLumaFilter: LumaLowpass = LumaLowpass.notch,
        chromaLowpassIn: ChromaLowpass = ChromaLowpass.full,
        chromaDemodulation: ChromaDemodulationFilter = ChromaDemodulationFilter.box,
        lumaSmear: Float = 0,
        compositePreemphasis: Float16 = 1,
        videoScanlinePhaseShift: PhaseShift = PhaseShift.degrees180,
        videoScanlinePhaseShiftOffset: Int = 0,
        headSwitchingEnabled: Bool = true,
        headSwitching: HeadSwitchingSettings = HeadSwitchingSettings.default,
        trackingNoise: TrackingNoiseSettings? = TrackingNoiseSettings.default,
        compositeNoise: FBMNoiseSettings = FBMNoiseSettings.compositeNoiseDefault,
        ringingEnabled: Bool = true,
        ringing: RingingSettings = RingingSettings.default,
        lumaNoise: FBMNoiseSettings? = FBMNoiseSettings.lumaNoiseDefault,
        chromaNoise: FBMNoiseSettings = FBMNoiseSettings.chromaNoiseDefault,
        snowIntensity: Float = 0.003,
        snowAnisotropy: Float = 0.5,
        chromaPhaseNoiseIntensity: Float16 = 0.001,
        chromaPhaseError: Float16 = 0,
        chromaDelay: (Float16, Int) = (0, 0),
        isVHSEnabled: Bool = true,
        vhsSettings: VHSSettings = VHSSettings.default,
        chromaVertBlend: Bool = true,
        chromaLowpassOut: ChromaLowpass = ChromaLowpass.full,
        bandwidthScale: Float = 1
    ) {
        self.randomSeed = randomSeed
        self.useField = useField
        self.filterType = filterType
        self.inputLumaFilter = inputLumaFilter
        self.chromaLowpassIn = chromaLowpassIn
        self.chromaDemodulation = chromaDemodulation
        self.lumaSmear = lumaSmear
        self.compositePreemphasis = compositePreemphasis
        self.videoScanlinePhaseShift = videoScanlinePhaseShift
        self.videoScanlinePhaseShiftOffset = videoScanlinePhaseShiftOffset
        self.headSwitchingEnabled = headSwitchingEnabled
        self.headSwitching = headSwitching
        self.trackingNoise = trackingNoise
        self.compositeNoise = compositeNoise
        self.ringingEnabled = ringingEnabled
        self.ringing = ringing
        self.lumaNoise = lumaNoise
        self.chromaNoise = chromaNoise
        self.snowIntensity = snowIntensity
        self.snowAnisotropy = snowAnisotropy
        self.chromaPhaseNoiseIntensity = chromaPhaseNoiseIntensity
        self.chromaPhaseError = chromaPhaseError
        self.chromaDelay = chromaDelay
        self.isVHSEnabled = isVHSEnabled
        self.vhsSettings = vhsSettings
        self.chromaVertBlend = chromaVertBlend
        self.chromaLowpassOut = chromaLowpassOut
        self.bandwidthScale = bandwidthScale
    }
}

enum ChromaDemodulationFilter: Int {
    case box
    case notch
    case oneLineComb
    case twoLineComb
}

enum UseField: Int, CaseIterable, Identifiable {
    case alternating = 0
    case upper
    case lower
    case both
    case interleavedUpper
    case interleavedLower
    
    var id: Int {
        rawValue
    }
}

enum FilterType: Int, Identifiable, CaseIterable {
    case constantK
    case butterworth
    
    var id: Int {
        rawValue
    }
}

enum LumaLowpass: Int, Identifiable, CaseIterable {
    case none
    case box
    case notch
    
    var id: Int {
        rawValue
    }
}

enum ChromaLowpass: Int, Identifiable, CaseIterable {
    case none
    case light
    case full
    
    var id: Int {
        rawValue
    }
}

enum PhaseShift: UInt, Identifiable, CaseIterable {
    case degrees0 = 0
    case degrees90
    case degrees180
    case degrees270
    
    var id: UInt {
        rawValue
    }
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

extension FBMNoiseSettings {
    static let compositeNoiseDefault = FBMNoiseSettings(
        frequency: 0.5,
        intensity: 0.01,
        detail: 1
    )
    
    static let lumaNoiseDefault = FBMNoiseSettings(
        frequency: 0.5,
        intensity: 0.05,
        detail: 1
    )
    
    static let chromaNoiseDefault = FBMNoiseSettings(
        frequency: 0.05,
        intensity: 0.1,
        detail: 1
    )
}

struct RingingSettings {
    var frequency: Float
    var power: Float
    var intensity: Float16
}

struct VHSSettings {
    var tapeSpeedEnabled: Bool
    var tapeSpeed: VHSTapeSpeed
    var chromaLoss: Float
    var sharpenEnabled: Bool
    var sharpen: VHSSharpenSettings
    var edgeWaveEnabled: Bool
    var edgeWave: VHSEdgeWaveSettings
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
