//
//  ContentView.swift
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-05-23.
//

import SwiftUI
import UIKit

struct ContentView: View {
    typealias InputLuma = NTSCFilter.InputLuma
    
    @State private var intensity: CGFloat = 0
    @State private var inputLuma: InputLuma = .box
    var body: some View {
        VStack {
            CameraView(filter: NTSCFilter(), lumaLowpass: $inputLuma)
            Picker(selection: $inputLuma, content: {
                ForEach(InputLuma.allCases) { luma in
                    Text(luma.rawValue)
                        .tag(luma)
                }
            }, label: {
                Text("Input Luma")
            })
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
