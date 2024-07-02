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
        XCTAssertEqual(try iteratorThing.next(), "a")
        XCTAssertEqual(try iteratorThing.next(), "b")
        XCTAssertEqual(try iteratorThing.last, "b")
        XCTAssertEqual(try iteratorThing.next(), "c")
        XCTAssertEqual(try iteratorThing.last, "c")
        XCTAssertEqual(try iteratorThing.last, "c")
        XCTAssertEqual(try iteratorThing.next(), "a")
        XCTAssertEqual(try iteratorThing.last, "a")
    }
}
