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
    var body: some View {
        VStack {
            CameraView(enableFilter: $enableFilter)
            Toggle("Enable filter?", isOn: $enableFilter)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
