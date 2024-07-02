//
//  ntsc_mtl_demoApp.swift
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-05-23.
//

import SwiftUI

#if TESTING
@main
struct TestApp: App {
    var body: some Scene {
        WindowGroup {
            Text("Testing...")
        }
    }
}

#else
@main
struct ntsc_mtl_demoApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
#endif

