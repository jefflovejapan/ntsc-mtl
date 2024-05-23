//
//  ContentView.swift
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-05-23.
//

import SwiftUI
import UIKit

struct ContentView: View {
    var body: some View {
        ZStack {
            Color.blue
            GeometryReader { proxy in
                CameraView(filter: NTSCFilter())
                    .frame(width: proxy.size.width, height: proxy.size.height)
            }
            .border(Color.red)
        }
    }
}

#Preview {
    ContentView()
}
