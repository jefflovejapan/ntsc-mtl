//
//  ContentView.swift
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-05-23.
//

import SwiftUI
import UIKit

struct ContentView: View {
    private let uiImage: UIImage
    init() {
        let url = Bundle.main.url(forResource: "michael", withExtension: "jpeg")!
        let ciImage = CIImage(contentsOf: url)
        let filter = NTSCFilter()
        filter.inputImage = ciImage
        let outputImage = filter.outputImage!
        let ciContext = CIContext()
        let cgImage = ciContext.createCGImage(outputImage, from: outputImage.extent)!
        let uiImage = UIImage(cgImage: cgImage)
        self.uiImage = uiImage
    }
    
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
