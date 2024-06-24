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
    @Binding var resolution: Resolution
    @Bindable var effect: NTSCEffect
    
    var body: some View {
        ScrollView {
            VStack {
                Toggle(isOn: $enableFilter, label: {
                    Text("Enable filter?")
                })
                resolutionView
                interlaceView
                blackLineBorderView
                colorBleedView
                vhsView
            }
        }
        .background(Color.green.opacity(0.2))
    }
    
    private var resolutionView: some View {
        HStack {
            Text("Resolution")
            Picker(selection: $resolution, content: {
                ForEach(Resolution.allCases) { res in
                    Text(name(resolution: res))
                        .tag(res)
                }
            }, label: {
                Text("Resolution")
            })
        }
    }
    
    private var interlaceView: some View {
        HStack {
            Text("Interlace Mode")
            Picker(selection: $effect.interlaceMode, content: {
                ForEach(InterlaceMode.allCases) { mode in
                    Text(name(interlaceMode: mode))
                        .tag(mode)
                }
            }, label: { Text("Interlace Mode") })
        }
    }
    
    private var blackLineBorderView: some View {
        VStack {
            Toggle(isOn: $effect.blackLineBorderEnabled, label: {
                Text("Enable black line border")
            })
            if effect.blackLineBorderEnabled {
                VStack {
                    Text("Black line border percentage: \(Int(effect.blackLineBorderPct * 100))%")
                    Slider(value: $effect.blackLineBorderPct, in: 0...1)
                }
            }

        }
    }
    
    private var colorBleedView: some View {
        VStack {
            Toggle(isOn: $effect.colorBleedEnabled, label: {
                Text("Enable color bleed?")
            })
            Text("Color bleed x: \(Int(effect.colorBleedXOffset))")
            Slider(value: $effect.colorBleedXOffset, in: -100...100)
            Text("Color bleed y: \(Int(effect.colorBleedYOffset))")
            Slider(value: $effect.colorBleedYOffset, in: -100...100)
        }
    }
    
    private var vhsView: some View {
        VStack {
            Toggle(isOn: $effect.enableVHSEmulation, label: {
                Text("Enable VHS emulation?")
            })
            if effect.enableVHSEmulation {
                VStack {
                    Text("VHS edge wave: \(Int(effect.vhsEdgeWave))")
                    Slider(value: $effect.vhsEdgeWave, in: 0...10, label: {
                        Text("VHS edge wave")
                    })
                }
            }
            Text("Color bleed x: \(Int(effect.colorBleedXOffset))")
            Slider(value: $effect.colorBleedXOffset, in: -100...100)
            Text("Color bleed y: \(Int(effect.colorBleedYOffset))")
            Slider(value: $effect.colorBleedYOffset, in: -100...100)
            Text("VHS sharpening: \(effect.vhsSharpening.formatted(self.twoDecimalPlaces))")
            Slider(value: $effect.vhsSharpening, in: 1.0...5.0)
        }
    }
        
    private var twoDecimalPlaces: FloatingPointFormatStyle<Float> {
        FloatingPointFormatStyle.number.precision(.fractionLength(2))
    }
    
    
    private func name(interlaceMode: InterlaceMode) -> String {
        return interlaceMode.rawValue.localizedCapitalized
    }
    
    private func name(resolution: Resolution) -> String {
        switch resolution {
        case .res4K:
            return "4K"
        case .res1080p:
            return "1080p"
        case .res720p:
            return "720p"
        case .resVGA:
            return "VGA"
        }
    }
}

#Preview {
    @State var showControls: Bool = true
    @State var enableFilter: Bool = false
    @State var effect: NTSCEffect = NTSCEffect()
    @State var resolution: Resolution = .resVGA
    return ControlsView(showControls: $showControls, enableFilter: $enableFilter, resolution: $resolution, effect: effect)
}
