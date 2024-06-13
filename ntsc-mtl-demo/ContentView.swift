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
            CameraView(enableFilter: $enableFilter)
                .padding()
            VStack {
                Spacer()
                if showControls {
                    ControlsView(showControls: $showControls, enableFilter: $enableFilter)
                        .frame(height: 300)
                        .transition(.move(edge: .trailing))
                }
                HStack {
                    Spacer()
                    Button(showControls ? "hide controls" : "show controls", systemImage: "slider.horizontal.3", action: {
                        withAnimation {
                            showControls.toggle()
                        }
                    })
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
