//
//  ContentView.swift
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-05-23.
//

import SwiftUI
import UIKit

struct ContentView: View {
    @State private var uiImage: UIImage
    init() {
        let url = Bundle.main.url(forResource: "michael", withExtension: "jpeg")!
        let ciImage = CIImage(contentsOf: url)
        let filter = HDRZebraFilter()
        filter.inputImage = ciImage
        let outputImage = filter.outputImage!
        _uiImage = State.init(initialValue: UIImage(ciImage: outputImage))
    }
    
    var body: some View {
        VStack {
            Image(uiImage: uiImage)
                .resizable()
                
            Text("It's me, Michael!")
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
