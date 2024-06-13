//
//  ControlsView.swift
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-06-13.
//

import SwiftUI

struct ControlsView: View {
    @Binding var showControls: Bool
    var body: some View {
        List(content: {
            Button.init("Hide controls", systemImage: "xmark", action: {
                showControls.toggle()
            })
        })
    }
}

#Preview {
    @State var showControls: Bool = true
    return ControlsView(showControls: $showControls)
}
