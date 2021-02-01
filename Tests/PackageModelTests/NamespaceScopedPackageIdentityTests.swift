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
    
    func testNormalizationInsensitivity() {
        // Combining sequences
        XCTAssertEqual(
            ID("@mona/E\u{0301}clair"), // ◌́ COMBINING ACUTE ACCENT (U+0301)
            ID("@mona/\u{00C9}clair") // É LATIN CAPITAL LETTER E WITH ACUTE (U+00C9)
        )

        // Ordering of combining marks
        XCTAssertEqual(
            // ◌̇ COMBINING DOT ABOVE (U+0307)
            // ◌̣ COMBINING DOT BELOW (U+0323)
            ID("@mona/q\u{0307}\u{0323}"),
            ID("@mona/q\u{0323}\u{0307}")
        )

        // Hangul & conjoining jamo
        XCTAssertEqual(
            ID("@mona/\u{AC00}"), // 가 HANGUL SYLLABLE GA (U+AC00)
            ID("@mona/\u{1100}\u{1161}") // ᄀ HANGUL CHOSEONG KIYEOK (U+1100) + ᅡ HANGUL JUNGSEONG A (U+1161)
        )

        // Singleton equivalence
        XCTAssertEqual(
            ID("@mona/\u{03A9}"), // Ω GREEK CAPITAL LETTER OMEGA (U+03A9)
            ID("@mona/\u{1D6C0}") // 𝛀 MATHEMATICAL BOLD CAPITAL OMEGA (U+1D6C0)
        )

        // Font variants
        XCTAssertEqual(
            ID("@mona/ℌello"), // ℌ BLACK-LETTER CAPITAL H (U+210C)
            ID("@mona/hello")
        )

        // Circled variants
        XCTAssertEqual(
            ID("@mona/①"), // ① CIRCLED DIGIT ONE (U+2460)
            ID("@mona/1")
        )

        // Width variants
        XCTAssertEqual(
            ID("@mona/ＬｉｎｋｅｄＬｉｓｔ"), // Ｌ FULLWIDTH LATIN CAPITAL LETTER L (U+FF2C)
            ID("@mona/LinkedList")
        )

        XCTAssertEqual(
            ID("@mona/ｼｰｻｲﾄﾞﾗｲﾅｰ"), // ｼ HALFWIDTH KATAKANA LETTER SI (U+FF7C)
            ID("@mona/シーサイドライナー")
        )

        // Ligatures
        XCTAssertEqual(
            ID("@mona/ǅungla"), // ǅ LATIN CAPITAL LETTER D WITH SMALL LETTER Z WITH CARON (U+01C5)
            ID("@mona/dzungla")
        )
    }

    func testValidIdentifiers() {
        XCTAssertNotNil(ID("@1/A"))
        XCTAssertNotNil(ID("@mona/LinkedList"))
        XCTAssertNotNil(ID("@m-o-n-a/LinkedList"))
        XCTAssertNotNil(ID("@mona/Linked_List"))
        XCTAssertNotNil(ID("@mona/قائمةمرتبطة"))
        XCTAssertNotNil(ID("@mona/链表"))
        XCTAssertNotNil(ID("@mona/רשימה_מקושרת"))
        XCTAssertNotNil(ID("@mona/รายการที่เชื่อมโยง"))
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
        XCTAssertNil(ID("@mona/🔗List")) // emoji
        XCTAssertNil(ID("@mona/Linked-List")) // hyphen
        XCTAssertNil(ID("@mona/LinkedList.swift")) // dot
        XCTAssertNil(ID("@mona/i⁹")) // superscript numeral
        XCTAssertNil(ID("@mona/i₉")) // subscript numeral
        XCTAssertNil(ID("@mona/㌀")) // squared characters
    }
}
