//
//  IteratorThing.swift
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-06-07.
//

import Foundation

class IteratorThing<A> {
    typealias Element = A
    let vals: Array<Element>
    var currentIndex = 0
    
    init(vals: Array<Element>) {
        self.vals = vals
    }
    
    func next() -> Element? {
        defer { currentIndex = (currentIndex + 1) % vals.count }
        if vals.indices.contains(currentIndex) {
            return vals[currentIndex]
        }
        return nil
    }
    
    var last: Element? {
        let prevIndex = currentIndex - 1
        if vals.indices.contains(prevIndex) {
            return vals[prevIndex]
        } else {
            let lastIndex = vals.endIndex - 1
            return vals.indices.contains(lastIndex) ? vals[lastIndex] : nil
        }
    }
}
