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
    var body: some View {
        ScrollView {
            VStack {
                Toggle(isOn: $enableFilter, label: {
                    Text("Enable filter?")
                })
            }
        }
        .border(Color.red)
    }
}

#Preview {
    @State var showControls: Bool = true
    @State var enableFilter: Bool = false
    return ControlsView(showControls: $showControls, enableFilter: $enableFilter)
}
