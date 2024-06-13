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
    
    private func name(for filterType: FilterType) -> String {
        switch filterType {
        case .constantK:
            return "Constant K"
        case .butterworth:
            return "Butterworth"
        }
    }
    var body: some View {
        ScrollView {
            VStack {
                Toggle(isOn: $enableFilter, label: {
                    Text("Enable filter?")
                })
                Picker(selection: $effect.filterType, content: {
                    ForEach(FilterType.allCases) { filterType in
                        Text(name(for: filterType))
                            .tag(filterType)
                    }
                }, label: {
                    Text("Filter Type")
                })
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
        .border(Color.red)
    }
}

#Preview {
    @State var showControls: Bool = true
    @State var enableFilter: Bool = false
    @State var effect: NTSCEffect = NTSCEffect()
    return ControlsView(showControls: $showControls, enableFilter: $enableFilter, effect: effect)
}
