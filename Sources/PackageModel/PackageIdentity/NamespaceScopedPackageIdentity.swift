/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2014 - 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See http://swift.org/LICENSE.txt for license information
 See http://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/**
 A namespace-scoped package identifier.

 A package *namespace* designates a single individual or organization
 within a package registry.
 A namespace consists of
 an at-sign (`@`) followed by alphanumeric characters and hyphens.
 Hyphens may not occur at the beginning or end,
 nor consecutively within a package namespace.
 The maximum length of a package namespace is 40 characters.
 A valid package namespace matches the following regular expression pattern:

 ```regexp
 \A@[a-zA-Z\d](?:[a-zA-Z\d]|-(?=[a-zA-Z\d])){0,39}\z
 ```

 A package's *name* is specified by the `name` parameter
 provided in its manifest (`Package.swift`) file.
 A package name must be unique within the scope of its namespace.

 The maximum length of a package namespace is 128 characters.
 A valid package namespace matches the following regular expression pattern:

 ```regexp
 \A\p{XID_Start}\p{XID_Continue}{0,127}\z
 ```

 > For more information,
 > see [Unicode Identifier and Pattern Syntax][UAX31].

 Package namespaces are case-insensitive
 (for example, `mona` ≍ `MONA`).
 Package names are
 case-insensitive
 (for example, `mona` ≍ `MONA`),
 diacritic-insensitive
 (for example, `Å` ≍ `A`), and
 width-insensitive
 (for example, `Ａ` ≍ `A`).
 Package names are compared using
 [Normalization Form Compatible Composition (NFKC)][UAX15].

 [UAX15]: http://www.unicode.org/reports/tr15/ "Unicode Technical Report #15: Unicode Normalization Forms"
 [UAX31]: http://www.unicode.org/reports/tr31/ "Unicode Technical Report #31: Unicode Identifier and Pattern Syntax"
 */
struct NamespaceScopedPackageIdentity {
    /// The package namespace.
    var namespace: String

    /// The package name.
    var name: String

    /// Creates a namespace-scoped identity from a string, if valid.
    init?(_ string: String) {
        guard !string.isEmpty,
              let separatorIndex = string.firstIndex(of: "/"),
              separatorIndex != string.endIndex
        else {
            return nil
        }

        do {
            let namespace = string.prefix(upTo: separatorIndex)
            guard namespace.count <= 40,
                  case let (initial, rest)? = namespace.headAndTail,
                  initial == "@",
                  case let (head, tail)? = rest.headAndTail,
                  head.isAlphanumeric,
                  tail.allSatisfy({ $0.isAlphanumeric || $0 == "-" }),
                  rest.first != "-", rest.last != "-", !rest.containsContiguousHyphens
            else {
                return nil
            }
            self.namespace = String(namespace)
        }

        do {
            let name = string.suffix(from: string.index(after: separatorIndex))
            let unicodeScalars = name.unicodeScalars
            guard name.count <= 128,
                  case let (head, tail)? = unicodeScalars.headAndTail,
                  head.properties.isXIDStart,
                  tail.allSatisfy({ $0.properties.isXIDContinue })
            else {
                return nil
            }
            self.name = String(name)
        }
    }
}

// MARK: - Equatable & Comparable

extension NamespaceScopedPackageIdentity: Equatable, Comparable {
    private static func compare(_ lhs: NamespaceScopedPackageIdentity, _ rhs: NamespaceScopedPackageIdentity) -> ComparisonResult {
        let lhs = lhs.description.precomposedStringWithCompatibilityMapping
        let rhs = rhs.description.precomposedStringWithCompatibilityMapping
        return lhs.compare(rhs, options: [.caseInsensitive, .diacriticInsensitive])
    }

    static func == (lhs: NamespaceScopedPackageIdentity, rhs: NamespaceScopedPackageIdentity) -> Bool {
        compare(lhs, rhs) == .orderedSame
    }

    static func < (lhs: NamespaceScopedPackageIdentity, rhs: NamespaceScopedPackageIdentity) -> Bool {
        compare(lhs, rhs) == .orderedAscending
    }

    static func > (lhs: NamespaceScopedPackageIdentity, rhs: NamespaceScopedPackageIdentity) -> Bool {
        compare(lhs, rhs) == .orderedDescending
    }
}

// MARK: - Hashable

extension NamespaceScopedPackageIdentity: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(description.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil))
    }
}

// MARK: - CustomStringConvertible

extension NamespaceScopedPackageIdentity: CustomStringConvertible {
    var description: String {
        "\(namespace)/\(name)"
    }
}

// MARK: -

fileprivate extension Collection {
    var headAndTail: (head: Element, tail: SubSequence)? {
        guard let head = first else { return nil }
        return (head, dropFirst())
    }
}

fileprivate extension StringProtocol {
    var containsContiguousHyphens: Bool {
        guard var previous = first else { return false }
        for character in suffix(from: startIndex) {
            defer { previous = character }
            if character == "-" && previous == "-" {
                return true
            }
        }

        return false
    }
}

fileprivate extension Character {
    var isAlphanumeric: Bool {
        isASCII && (isLetter || isNumber)
    }
}
