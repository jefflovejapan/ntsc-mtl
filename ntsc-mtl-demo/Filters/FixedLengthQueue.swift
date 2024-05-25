//
//  FixedLengthQueue.swift
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-05-25.
//

import Foundation

struct FixedLengthQueue<T> {
    private(set) var elements: [T]
    private let capacity: Int

    init(capacity: Int) {
        self.capacity = capacity
        self.elements = []
    }

    mutating func push(_ element: T) {
        if elements.count == capacity {
            elements.removeLast()
        }
        elements.insert(element, at: 0)
    }
}
