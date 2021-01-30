/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2014 - 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See http://swift.org/LICENSE.txt for license information
 See http://swift.org/CONTRIBUTORS.txt for Swift project authors
 */

import XCTest

import TSCBasic

@testable import PackageModel

fileprivate typealias ID = NamespaceScopedPackageIdentity

final class NamespaceScopedPackageIdentityTests: XCTestCase {
    func testIdentifierInitialization() {
        let identity = ID("@mona/LinkedList")
        XCTAssertNotNil(identity)
        XCTAssertEqual(identity?.namespace, "@mona")
        XCTAssertEqual(identity?.name, "LinkedList")
    }

    func testCaseInsensitivity() {
        XCTAssertEqual(
            ID("@mona/linkedlist"),
            ID("@MONA/LINKEDLIST")
        )
    }

    func testDiacriticInsensitivity() {
        XCTAssertEqual(
            ID("@mona/LinkedList"),
            ID("@mona/LïnkédLîst")
        )
    }

    func testWidthInsensitivity() {
        XCTAssertEqual(
            ID("@mona/LinkedList"),
            ID("@mona/ＬｉｎｋｅｄＬｉｓｔ")
        )
    }

    func testNormalizationInsensitivity() {
        XCTAssertEqual(
            ID("@mona/ǅungla"),
            ID("@mona/dzungla")
        )
    }

    func testValidIdentifiers() {
        XCTAssertNotNil(ID("@1/A"))
        XCTAssertNotNil(ID("@mona/LinkedList"))
        XCTAssertNotNil(ID("@m-o-n-a/LinkedList"))
        XCTAssertNotNil(ID("@mona/Linked_List"))
    }

    func testInvalidIdentifiers() {
        // Invalid identifiers
        XCTAssertNil(ID("")) // empty
        XCTAssertNil(ID("/")) // empty namespace and name
        XCTAssertNil(ID("@/")) // empty namespace and name with leading @
        XCTAssertNil(ID("@mona")) // namespace only
        XCTAssertNil(ID("LinkedList")) // name only

        // Invalid namespaces
        XCTAssertNil(ID("mona/LinkedList")) // missing @
        XCTAssertNil(ID("@/LinkedList")) // empty namespace
        XCTAssertNil(ID("@-mona/LinkedList")) // leading hyphen
        XCTAssertNil(ID("@mona-/LinkedList")) // trailing hyphen
        XCTAssertNil(ID("@mo--na/LinkedList")) // consecutive hyphens

        // Invalid names
        XCTAssertNil(ID("@mona/")) // empty name
        XCTAssertNil(ID("@mona/_LinkedList")) // underscore in start
        XCTAssertNil(ID("@mona/🔗List")) // invalid emoji
        XCTAssertNil(ID("@mona/Linked-List")) // invalid hyphen
        XCTAssertNil(ID("@mona/LinkedList.swift")) // invalid dot
    }
}
