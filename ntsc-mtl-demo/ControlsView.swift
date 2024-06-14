//
//  ControlsView.swift
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-06-13.
//

import SwiftUI

struct ControlsView: View {
    @Binding var showControls: Bool
    @Binding var enableFilter: Bool
    @Bindable var effect: NTSCEffect
    
    var body: some View {
        ScrollView {
            VStack {
                Toggle(isOn: $enableFilter, label: {
                    Text("Enable filter?")
                })
                VStack(alignment: .leading) {
                    Text("Bandwidth scale")
                    Slider.init(value: $effect.bandwidthScale, in: 0.125...8, label: {
                        Text(effect.bandwidthScale.formatted(.number))
                    })
                    .padding(.leading)
                }
                HStack {
                    Text("Input luma")
                    Spacer()
                    Picker(selection: $effect.inputLumaFilter, content: {
                        ForEach(LumaLowpass.allCases) { lowpass in
                            Text(name(lumaLowpass: lowpass))
                                .tag(lowpass)
                        }
                    }, label: {
                        Text("Input Luma")
                    })
                }
                HStack {
                    Text("Filter type")
                    Spacer()
                    Picker(selection: $effect.filterType, content: {
                        ForEach(FilterType.allCases) { filterType in
                            Text(name(filterType: filterType))
                                .tag(filterType)
                        }
                    }, label: {
                        Text("Filter Type")
                    })
                }
                HStack {
                    Text("Chroma lowpass in")
                    Spacer()
                    Picker(selection: $effect.chromaLowpassIn, content: {
                        ForEach(ChromaLowpass.allCases) { lp in
                            Text(name(chromaLowpass: lp))
                                .tag(lp)
                        }
                    }, label: {
                        Text("Chroma lowpass in")
                    })
                }
                
                HStack {
                    Text("Chroma phase shift")
                    Spacer()
                    Picker(selection: $effect.videoScanlinePhaseShift, content: {
                        ForEach(PhaseShift.allCases) { phaseShift in
                            Text(name(phaseShift: phaseShift))
                                .tag(phaseShift)
                        }
                    }, label: {
                        Text("Video scanline phase shift")
                    })
                }
                Stepper("Chroma phase shift offset: \(effect.videoScanlinePhaseShiftOffset)", value: $effect.videoScanlinePhaseShiftOffset, in: 0...4)
                VStack {
                    Text("Chroma phase error")
                    Slider(value: $effect.chromaPhaseError, in: 0...1)
                        .padding(.leading)
                }
                VStack {
                    Text("Composite preemphasis")
                    Slider(value: $effect.compositePreemphasis, in: -1...2)
                        .padding(.leading)
                }
                Toggle(isOn: $effect.headSwitchingEnabled, label: {
                    Text("Head switching")
                })
                if effect.headSwitchingEnabled {
                    Section("Head switching", content: {
                        Stepper(value: $effect.headSwitching.height, in: 0...24, label: {
                            Text("Height")
                        })
                        Stepper(value: $effect.headSwitching.offset, in: 0...24, label: {
                            Text("Offset")
                        })
                        VStack {
                            Text("Horizontal shift")
                            Slider(value: $effect.headSwitching.horizShift, in: -100...100)
                        }
                    })
                }
                VStack {
                    Text("Luma smear")
                    Slider(value: $effect.lumaSmear, in: 0...1)
                        .padding(.leading)
                }
                Toggle(isOn: $effect.ringingEnabled, label: {
                    Text("Ringing")
                })

                if effect.ringingEnabled {
                    Section("Ringing", content: {
                        VStack {
                            Text("Frequency")
                            Slider(value: $effect.ringing.frequency, in: 0...1)
                        }
                        VStack {
                            Text("Power")
                            Slider(value: $effect.ringing.power, in: 1...10)
                        }
                        VStack {
                            Text("Intensity")
                            Slider(value: $effect.ringing.intensity, in: 0...10)
                        }  
                    })
                }
                VStack {
                    Text("Chroma phase noise")
                    Slider(value: $effect.chromaPhaseNoiseIntensity, in: 0...1)
                        .padding(.leading)
                }
//                VStack(alignment: .leading) {
//                    Text("Luma smear")
//                    Slider.init(value: $effect.lumaSmear, in: 0...1, label: {
//                        Text(effect.lumaSmear.formatted(.number))
//                    })
//                    .padding(.leading)
//                }
                
                /*
                 What should actually be supported?
                 
                 - bandwidth scale
                 - input luma (LumaLowpass)
                 - luma box filter: LumaBoxTextureFilter
                - lumaNotchFilter: IIRTextureFilter
                 - chroma lowpass (ChromaLowpass)
                 - chroma into luma (PhaseShift, phaseShiftOffset)
                 - compositePreemphasis (IIR)
                 - compositeNoise
                 - ringing
                 */
            }
        }
    }
    
    private func name(filterType: FilterType) -> String {
        switch filterType {
        case .constantK:
            return "Constant K"
        case .butterworth:
            return "Butterworth"
        }
    }
    
    private func name(lumaLowpass: LumaLowpass) -> String {
        switch lumaLowpass {
        case .none:
            return "None"
        case .box:
            return "Box"
        case .notch:
            return "Notch"
        }
    }
    
    private func name(phaseShift: PhaseShift) -> String {
        switch phaseShift {
        case .degrees0:
            "0"
        case .degrees90:
            "90"
        case .degrees180:
            "180"
        case .degrees270:
            "270"
        }
    }
    
    private func name(chromaLowpass: ChromaLowpass) -> String {
        switch chromaLowpass {
        case .none:
            return "None"
        case .light:
            return "Light"
        case .full:
            return "Full"
        }
    }
}

#Preview {
    @State var showControls: Bool = true
    @State var enableFilter: Bool = false
    @State var effect: NTSCEffect = NTSCEffect()
    return ControlsView(showControls: $showControls, enableFilter: $enableFilter, effect: effect)
}
