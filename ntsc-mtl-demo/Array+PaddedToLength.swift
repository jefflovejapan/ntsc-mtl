//
//  Array+PaddedToLength.swift
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-06-07.
//

import Foundation

extension Array {
    func padded(toLength length: Int, with element: Element) -> Self {
        var newArray = Array<Element>(repeating: element, count: length)
        for idx in self.indices {
            newArray[idx] = self[idx]
        }
        return newArray
    }
}
