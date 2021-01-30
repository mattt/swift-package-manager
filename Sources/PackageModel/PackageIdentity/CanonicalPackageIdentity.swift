/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2014 - 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See http://swift.org/LICENSE.txt for license information
 See http://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A canonicalized package identity.
///
/// A package may declare external packages as dependencies in its manifest.
/// Each external package is uniquely identified by the location of its source code.
///
/// An external package dependency may itself have one or more external package dependencies,
/// known as _transitive dependencies_.
/// When multiple packages have dependencies in common,
/// Swift Package Manager determines which version of that package should be used
/// (if any exist that satisfy all specified requirements)
/// in a process called package resolution.
///
/// External package dependencies are located by a URL
/// (which may be an implicit `file://` URL in the form of a file path).
/// For the purposes of package resolution,
/// package URLs are case-insensitive (mona ≍ MONA)
/// and normalization-insensitive (n + ◌̃ ≍ ñ).
/// Swift Package Manager takes additional steps to canonicalize URLs
/// to resolve insignificant differences between URLs.
/// For example,
/// the URLs `https://example.com/Mona/LinkedList` and `git@example.com:mona/linkedlist`
/// are equivalent, in that they both resolve to the same source code repository,
/// despite having different scheme, authority, and path components.
///
/// The `PackageIdentity` type canonicalizes package locations by
/// performing the following operations:
///
/// * Removing the scheme component, if present
///   ```
///   https://example.com/mona/LinkedList → example.com/mona/LinkedList
///   ```
/// * Removing the userinfo component (preceded by `@`), if present:
///   ```
///   git@example.com/mona/LinkedList → example.com/mona/LinkedList
///   ```
/// * Removing the port subcomponent, if present:
///   ```
///   example.com:443/mona/LinkedList → example.com/mona/LinkedList
///   ```
/// * Replacing the colon (`:`) preceding the path component in "`scp`-style" URLs:
///   ```
///   git@example.com:mona/LinkedList.git → example.com/mona/LinkedList
///   ```
/// * Expanding the tilde (`~`) to the provided user, if applicable:
///   ```
///   ssh://mona@example.com/~/LinkedList.git → example.com/~mona/LinkedList
///   ```
/// * Transcoding internationalized domain names using Punycode
///   and prepending the ASCII Compatible Encoding (ACE) prefix, "xn--",
///   if applicable:
///   ```
///   schlüssel.tld/mona/LinkedList → xn--schlssel-95a.tld/mona/LinkedList
///   ```
/// * Removing percent-encoding from the path component, if applicable:
///   ```
///   example.com/mona/%F0%9F%94%97List → example.com/mona/🔗List
///   ```
/// * Removing the `.git` file extension from the path component, if present:
///   ```
///   example.com/mona/LinkedList.git → example.com/mona/LinkedList
///   ```
/// * Removing the trailing slash (`/`) in the path component, if present:
///   ```
///   example.com/mona/LinkedList/ → example.com/mona/LinkedList
///   ```
/// * Removing the fragment component (preceded by `#`), if present:
///   ```
///   example.com/mona/LinkedList#installation → example.com/mona/LinkedList
///   ```
/// * Removing the query component (preceded by `?`), if present:
///   ```
///   example.com/mona/LinkedList?utm_source=forums.swift.org → example.com/mona/LinkedList
///   ```
/// * Adding a leading slash (`/`) for `file://` URLs and absolute file paths:
///   ```
///   file:///Users/mona/LinkedList → /Users/mona/LinkedList
///   ```
/// * Normalizing Windows local file system paths, when applicable:
///   ```
///   c:\user\mona\LinkedList → /user/mona/LinkedList
///   ```
/// * Normalizing Windows Universal Naming Convention (UNC) paths, when applicable:
///   ```
///   \\user\mona\LinkedList → /user/mona/LinkedList
///   ```
/// * Normalizing "long" Windows Universal Naming Convention (UNC) paths, when applicable:
///   ```
///   \\?\C:\user\mona\LinkedList → /user/mona/LinkedList
///   ```
/// * Normalizing Windows NT Object Manager paths, when applicable:
///   ```
///   \\??\C:\user\mona\LinkedList → /user/mona/LinkedList
///   ```
struct CanonicalPackageIdentity: PackageIdentityProvider, Equatable {
    /// A textual representation of this instance.
    public let description: String

    /// Instantiates an instance of the conforming type from a string representation.
    public init(_ string: String) {
        var description = string.precomposedStringWithCanonicalMapping.lowercased()

        // Normalize Windows path prefix, if present
        let isWindowsPath = description.normalizeWindowsPathPrefixIfPresent()

        // Remove the scheme component, if present.
        let detectedScheme = description.dropSchemeComponentPrefixIfPresent()

        // Remove the userinfo subcomponent (user / password), if present.
        if case (let user, _)? = description.dropUserinfoSubcomponentPrefixIfPresent() {
            // If a user was provided, perform tilde expansion, if applicable.
            description.replaceFirstOccurenceIfPresent(of: "/~/", with: "/~\(user)/")
        }

        // Remove the port subcomponent, if present.
        description.removePortComponentIfPresent()

        // Remove the fragment component, if present.
        description.removeFragmentComponentIfPresent()

        // Remove the query component, if present.
        description.removeQueryComponentIfPresent()

        // Accomodate "`scp`-style" SSH URLs
        if detectedScheme == nil || detectedScheme == "ssh" {
            description.replaceFirstOccurenceIfPresent(of: ":", before: description.firstIndex(of: "/"), with: "/")
        }

        // Split the remaining string into path components,
        // filtering out empty path components and removing valid percent encodings.
        var components = description.split(omittingEmptySubsequences: true, whereSeparator: { $0.isSeparator })
            .compactMap { $0.removingPercentEncoding ?? String($0) }

        // Remove the `.git` suffix from the last path component.
        var lastPathComponent = components.popLast() ?? ""
        lastPathComponent.removeSuffixIfPresent(".git")
        components.append(lastPathComponent)

        description = components.joined(separator: "/")

        // Prepend a leading slash for file URLs and paths
        if isWindowsPath || detectedScheme == "file" || string.first.flatMap({ $0.isSeparator }) ?? false {
            description.insert("/", at: description.startIndex)
        }

        // TODO: Implement PunyCode transcoding
        assert(description.prefix(while: { $0 != "/" }).allSatisfy({ $0.isLetter || $0.isDigit || $0 == "-" || $0 == "." }), "canonical package identities must not contain internationalized domain name characters")

        self.description = description
    }
}

private extension Character {
    var isSeparator: Bool {
        return self == "/" || self == #"\"#
    }

    var isDigit: Bool {
        switch self {
        case "0", "1", "2", "3", "4", "5", "6", "7", "8", "9":
            return true
        default:
            return false
        }
    }

    var isAllowedInURLScheme: Bool {
        return isLetter || self.isDigit || self == "+" || self == "-" || self == "."
    }
}

private extension String {
    @discardableResult
    mutating func removePrefixIfPresent<T: StringProtocol>(_ prefix: T) -> Bool {
        guard hasPrefix(prefix) else { return false }
        removeFirst(prefix.count)
        return true
    }

    @discardableResult
    mutating func removeSuffixIfPresent<T: StringProtocol>(_ suffix: T) -> Bool {
        guard hasSuffix(suffix) else { return false }
        removeLast(suffix.count)
        return true
    }

    @discardableResult
    mutating func normalizeWindowsPathPrefixIfPresent() -> Bool {
        var normalized = removePrefixIfPresent(#"\\?\"#) || removePrefixIfPresent(#"\\??\"#)

        // Remove drive letter prefix (for example, "C:"
        if let first = first,
           first.isLetter,
           let secondIndex = index(startIndex, offsetBy: 1, limitedBy: endIndex),
           self[secondIndex] == ":"
        {
            self.removeSubrange(...secondIndex)
            normalized = true
        }

        if normalized {
            insert("/", at: startIndex)
        }

        return normalized
    }

    @discardableResult
    mutating func dropSchemeComponentPrefixIfPresent() -> String? {
        if let rangeOfDelimiter = range(of: "://"),
           self[startIndex].isLetter,
           self[..<rangeOfDelimiter.lowerBound].allSatisfy({ $0.isAllowedInURLScheme })
        {
            defer { self.removeSubrange(..<rangeOfDelimiter.upperBound) }

            return String(self[..<rangeOfDelimiter.lowerBound])
        }

        return nil
    }

    @discardableResult
    mutating func dropUserinfoSubcomponentPrefixIfPresent() -> (user: String, password: String?)? {
        if let indexOfAtSign = lastIndex(of: "@"),
           let indexOfFirstPathComponent = firstIndex(where: { $0.isSeparator }),
           indexOfAtSign < indexOfFirstPathComponent
        {
            defer { self.removeSubrange(...indexOfAtSign) }

            let userinfo = self[..<indexOfAtSign]
            var components = userinfo.split(separator: ":", maxSplits: 2, omittingEmptySubsequences: false)
            guard components.count > 0 else { return nil }
            let user = String(components.removeFirst())
            let password = components.last.map(String.init)

            return (user, password)
        }

        return nil
    }

    @discardableResult
    mutating func removePortComponentIfPresent() -> Bool {
        if let indexOfFirstPathComponent = firstIndex(where: { $0.isSeparator }),
           let startIndexOfPort = firstIndex(of: ":"),
           startIndexOfPort < endIndex,
           let endIndexOfPort = self[index(after: startIndexOfPort)...].lastIndex(where: { $0.isDigit }),
           endIndexOfPort <= indexOfFirstPathComponent
        {
            self.removeSubrange(startIndexOfPort ... endIndexOfPort)
            return true
        }

        return false
    }

    @discardableResult
    mutating func removeFragmentComponentIfPresent() -> Bool {
        if let index = firstIndex(of: "#") {
            self.removeSubrange(index...)
        }

        return false
    }

    @discardableResult
    mutating func removeQueryComponentIfPresent() -> Bool {
        if let index = firstIndex(of: "?") {
            self.removeSubrange(index...)
        }

        return false
    }

    @discardableResult
    mutating func replaceFirstOccurenceIfPresent<T: StringProtocol, U: StringProtocol>(
        of string: T,
        before index: Index? = nil,
        with replacement: U
    ) -> Bool {
        guard let range = range(of: string) else { return false }

        if let index = index, range.lowerBound >= index {
            return false
        }

        self.replaceSubrange(range, with: replacement)
        return true
    }
}

