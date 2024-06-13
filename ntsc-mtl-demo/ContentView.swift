//
//  ContentView.swift
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-05-23.
//

import SwiftUI
import UIKit

struct ContentView: View {
    @State private var intensity: CGFloat = 0
    @State private var enableFilter: Bool = false
    @State private var showControls: Bool = false
    var body: some View {
        ZStack {
            VStack {
                HStack {
                    Spacer()
                    Button(showControls ? "hide controls" : "show controls", systemImage: "slider.horizontal.3", action: {
                        showControls.toggle()
                    })
                }
                CameraView(enableFilter: $enableFilter)
            }
            if showControls {
                VStack {
                    Spacer()
                    ControlsView(showControls: $showControls)
                }
            }
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
