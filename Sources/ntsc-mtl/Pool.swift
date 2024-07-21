//
//  Pool.swift
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-06-07.
//

import Foundation

class Pool<A> {
    enum Error: Swift.Error {
        case noValidElement
    }
    typealias Element = A
    let vals: Array<Element>
    var currentIndex = 0
    
    init(vals: Array<Element>) {
        self.vals = vals
    }
    
    func next() throws -> Element {
        defer { currentIndex = (currentIndex + 1) % vals.count }
        if vals.indices.contains(currentIndex) {
            return vals[currentIndex]
        }
        throw Error.noValidElement
    }
    
    var last: Element {
        get throws {
            let prevIndex = currentIndex - 1
            if vals.indices.contains(prevIndex) {
                return vals[prevIndex]
            } else {
                let lastIndex = vals.endIndex - 1
                if vals.indices.contains(lastIndex) {
                    return vals[lastIndex]
                }
                throw Error.noValidElement
            }
        }
    }
}
