//
//  IteratorThingTests.swift
//  ntsc-mtl-demoTests
//
//  Created by Jeffrey Blagdon on 2024-06-07.
//

import XCTest
@testable import ntsc_mtl_demo

final class IteratorThingTests: XCTestCase {

    func testLooping() throws {
        let iteratorThing = IteratorThing(vals: ["a", "b", "c"])
        XCTAssertEqual(iteratorThing.next(), "a")
        XCTAssertEqual(iteratorThing.next(), "b")
        XCTAssertEqual(iteratorThing.last, "b")
        XCTAssertEqual(iteratorThing.next(), "c")
        XCTAssertEqual(iteratorThing.last, "c")
        XCTAssertEqual(iteratorThing.last, "c")
        XCTAssertEqual(iteratorThing.next(), "a")
        XCTAssertEqual(iteratorThing.last, "a")
    }
}
