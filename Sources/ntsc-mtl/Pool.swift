//
//  Pool.swift
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-06-07.
//

import Foundation

class Pool<A> {
    typealias Element = A
    let vals: Array<Element>
    var currentIndex = 0
    
    init(vals: Array<Element>) {
        self.vals = vals
    }
    
    func next() -> Element {
        defer { currentIndex = (currentIndex + 1) % vals.count }
        return vals[currentIndex]
    }
    
    var last: Element {
        let prevIndex = currentIndex - 1
        if vals.indices.contains(prevIndex) {
            return vals[prevIndex]
        } else {
            let lastIndex = vals.endIndex - 1
            return vals[lastIndex]
        }
    }
}
