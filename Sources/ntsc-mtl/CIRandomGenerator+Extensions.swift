//
//  CIRandomGenerator+Extensions.swift
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-06-25.
//

import Foundation
import CoreImage

extension CIFilter  {
    func image(size: CGSize, offset: CGSize) -> CIImage? {
        outputImage?.transformed(by: CGAffineTransform(translationX: offset.width, y: offset.height)).cropped(to: CGRect(origin: .zero, size: size))
    }
}
