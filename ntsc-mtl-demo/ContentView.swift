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
    var body: some View {
        VStack {
            CameraView(filter: NTSCFilter(), intensity: $intensity)
            HStack {
                Text("Intensity")
                Slider.init(value: $intensity, in: 0...1)
            }
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
