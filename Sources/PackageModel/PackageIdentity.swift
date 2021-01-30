/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2014 - 2020 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See http://swift.org/LICENSE.txt for license information
 See http://swift.org/CONTRIBUTORS.txt for Swift project authors
 */

import Foundation

import TSCBasic
import TSCUtility

/// When set to `false`,
/// `PackageIdentity` uses the canonical location of package dependencies as its identity.
/// Otherwise, only the last path component is used to identify package dependencies.
public var _useLegacyIdentities: Bool = true {
    willSet {
        PackageIdentity.provider = newValue ? LegacyPackageIdentity.self : CanonicalPackageIdentity.self
    }
}

internal protocol PackageIdentityProvider: CustomStringConvertible {
    init(_ string: String)
}

/// The canonical identifier for a package, based on its source location.
public struct PackageIdentity: Hashable, CustomStringConvertible {
    /// The underlying type used to create package identities.
    internal static var provider: PackageIdentityProvider.Type = LegacyPackageIdentity.self

    /// A textual representation of this instance.
    public let description: String

    /// Creates a package identity from a string.
    /// - Parameter string: A string used to identify a package.
    init(_ string: String) {
        self.description = Self.provider.init(string).description
    }

    /// Creates a package identity from a URL.
    /// - Parameter url: The package's URL.
    public init(url: String) { // TODO: Migrate to Foundation.URL
        self.init(url)
    }

    /// Creates a package identity from a file path.
    /// - Parameter path: An absolute path to the package.
    public init(path: AbsolutePath) {
        self.init(path.pathString)
    }
}

extension PackageIdentity: Comparable {
    public static func < (lhs: PackageIdentity, rhs: PackageIdentity) -> Bool {
        return lhs.description < rhs.description
    }
}

extension PackageIdentity: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let description = try container.decode(String.self)
        self.init(description)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.description)
    }
}

extension PackageIdentity: JSONMappable, JSONSerializable {
    public init(json: JSON) throws {
        guard case .string(let string) = json else {
            throw JSON.MapError.typeMismatch(key: "", expected: String.self, json: json)
        }

        self.init(string)
    }

    public func toJSON() -> JSON {
        return .string(self.description)
    }
}
