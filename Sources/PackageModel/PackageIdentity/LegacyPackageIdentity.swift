/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2014 - 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See http://swift.org/LICENSE.txt for license information
 See http://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

struct LegacyPackageIdentity: PackageIdentityProvider, Equatable {
    /// A textual representation of this instance.
    public let description: String

    /// Instantiates an instance of the conforming type from a string representation.
    public init(_ string: String) {
        self.description = Self.computeDefaultName(fromURL: string).lowercased()
    }

    /// Compute the default name of a package given its URL.
    public static func computeDefaultName(fromURL url: String) -> String {
        #if os(Windows)
        let isSeparator : (Character) -> Bool = { $0 == "/" || $0 == "\\" }
        #else
        let isSeparator : (Character) -> Bool = { $0 == "/" }
        #endif

        // Get the last path component of the URL.
        // Drop the last character in case it's a trailing slash.
        var endIndex = url.endIndex
        if let lastCharacter = url.last, isSeparator(lastCharacter) {
            endIndex = url.index(before: endIndex)
        }

        let separatorIndex = url[..<endIndex].lastIndex(where: isSeparator)
        let startIndex = separatorIndex.map { url.index(after: $0) } ?? url.startIndex
        var lastComponent = url[startIndex..<endIndex]

        // Strip `.git` suffix if present.
        if lastComponent.hasSuffix(".git") {
            lastComponent = lastComponent.dropLast(4)
        }

        return String(lastComponent)
    }
}
