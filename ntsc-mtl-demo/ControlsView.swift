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
//                Picker(selection: $effect.filterType, content: {
//                    ForEach(FilterType.allCases) { filterType in
//                        Text(name(for: filterType))
//                            .tag(filterType)
//                    }
//                }, label: {
//                    Text("Filter Type")
//                })
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
}

#Preview {
    @State var showControls: Bool = true
    @State var enableFilter: Bool = false
    @State var effect: NTSCEffect = NTSCEffect()
    return ControlsView(showControls: $showControls, enableFilter: $enableFilter, effect: effect)
}
