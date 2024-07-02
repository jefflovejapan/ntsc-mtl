import Foundation

extension Foundation.Bundle {
    static let module: Bundle = {
        let mainPath = Bundle.main.bundleURL.appendingPathComponent("ntsc-mtl_ntsc-mtl.bundle").path
        let buildPath = "/Users/jeff/Developer/recurse/ntsc-mtl/.build/arm64-apple-macosx/debug/ntsc-mtl_ntsc-mtl.bundle"

        let preferredBundle = Bundle(path: mainPath)

        guard let bundle = preferredBundle ?? Bundle(path: buildPath) else {
            // Users can write a function called fatalError themselves, we should be resilient against that.
            Swift.fatalError("could not load resource bundle: from \(mainPath) or \(buildPath)")
        }

        return bundle
    }()
}