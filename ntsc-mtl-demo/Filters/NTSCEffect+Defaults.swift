//
//  NTSCEffect+Defaults.swift
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-05-25.
//

import Foundation

extension NTSCEffect {
    static let `default` = defaultNTSCEffect()
    private static func defaultNTSCEffect() -> NTSCEffect {
        return NTSCEffect(
                randomSeed: 0,
                useField: UseField.interleavedUpper,
                filterType: FilterType.constantK,
                inputLumaFilter: LumaLowpass.notch,
                chromaLowpassIn: ChromaLowpass.full,
                chromaDemodulation: ChromaDemodulationFilter.box,
                lumaSmear: 0,
                compositePreemphasis: 1,
                videoScanlinePhaseShift: PhaseShift.degrees180,
                videoScanlinePhaseShiftOffset: 0,
                headSwitching: HeadSwitchingSettings.default,
                trackingNoise: TrackingNoiseSettings.default,
                compositeNoise: FBMNoiseSettings.compositeNoiseDefault,
                ringing: RingingSettings.default,
                lumaNoise: FBMNoiseSettings.lumaNoiseDefault,
                chromaNoise: FBMNoiseSettings.chromaNoiseDefault,
                snowIntensity: 0.003,
                snowAnisotropy: 0.5,
                chromaPhaseNoiseIntensity: 0.001,
                chromaPhaseError: 0.0,
                chromaDelay: (0.0, 0),
                vhsSettings: VHSSettings.default,
                chromaVertBlend: true,
                chromaLowpassOut: ChromaLowpass.full,
                bandwidthScale: 1
            )
    }
}

extension HeadSwitchingSettings {
    static let `default` = HeadSwitchingSettings(
        height: 8,
        offset: 3,
        horizShift: 72,
        midLine: .default
    )
}

extension HeadSwitchingMidLineSettings {
    static let `default` = HeadSwitchingMidLineSettings(
        position: 0.95,
        jitter: 0.03
    )
}

extension TrackingNoiseSettings {
    static let `default` = TrackingNoiseSettings(
        height: 24,
        waveIntensity: 5,
        snowIntensity: 0.05,
        snowAnisotropy: 0.5,
        noiseIntensity: 0.005
    )
}

extension RingingSettings {
    static let `default` = RingingSettings(
        frequency: 0.45,
        power: 4,
        intensity: 4
    )
}

extension VHSSettings {
    static let `default` = VHSSettings(
        tapeSpeedEnabled: true,
        tapeSpeed: .lp,
        chromaLoss: 0,
        sharpenEnabled: true,
        sharpen: .default,
        edgeWaveEnabled: true,
        edgeWave: .default
    )
}

extension VHSSharpenSettings {
    static let `default` = VHSSharpenSettings(
        intensity: 1,
        frequency: 1
    )
}

extension VHSEdgeWaveSettings {
    static let `default` = VHSEdgeWaveSettings(
        intensity: 1,
        speed: 4,
        frequency: 0.05,
        detail: 1
    )
}
