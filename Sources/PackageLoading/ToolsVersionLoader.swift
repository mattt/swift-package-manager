/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2014 - 2017 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See http://swift.org/LICENSE.txt for license information
 See http://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

import TSCBasic
import TSCUtility

import PackageModel

/// Protocol for the manifest loader interface.
public protocol ToolsVersionLoaderProtocol {

    /// Load the tools version at the give package path.
    ///
    /// - Parameters:
    ///   - path: The path to the package.
    ///   - fileSystem: The file system to use to read the file which contains tools version.
    /// - Returns: The tools version.
    /// - Throws: ToolsVersion.Error
    func load(at path: AbsolutePath, fileSystem: FileSystem) throws -> ToolsVersion
}

public class ToolsVersionLoader: ToolsVersionLoaderProtocol {

    let currentToolsVersion: ToolsVersion

    public init(currentToolsVersion: ToolsVersion = .currentToolsVersion) {
        self.currentToolsVersion = currentToolsVersion
    }

    public enum Error: Swift.Error, CustomStringConvertible {
        /// Package directory is inaccessible (missing, unreadable, etc).
        case inaccessiblePackage(path: AbsolutePath, reason: String)
        /// Package manifest file is inaccessible (missing, unreadable, etc).
        case inaccessibleManifest(path: AbsolutePath, reason: String)
        /// Malformed tools version specifier
        case malformedToolsVersion(specifier: String, currentToolsVersion: ToolsVersion)

        public var description: String {
            switch self {
            case .inaccessiblePackage(let packageDir, let reason):
                return "the package at '\(packageDir)' cannot be accessed (\(reason))"
            case .inaccessibleManifest(let manifestFile, let reason):
                return "the package manifest at '\(manifestFile)' cannot be accessed (\(reason))"
            case .malformedToolsVersion(let versionSpecifier, let currentToolsVersion):
                return "the tools version '\(versionSpecifier)' is not valid; consider using '// swift-tools-version:\(currentToolsVersion.major).\(currentToolsVersion.minor)' to specify the current tools version"
            }
        }
    }

    public func load(at path: AbsolutePath, fileSystem: FileSystem) throws -> ToolsVersion {
        // The file which contains the tools version.
        let file = try Manifest.path(atPackagePath: path, currentToolsVersion: currentToolsVersion, fileSystem: fileSystem)
        guard fileSystem.isFile(file) else {
            // FIXME: We should return an error from here but Workspace tests rely on this in order to work.
            // This doesn't really cause issues (yet) in practice though.
            return ToolsVersion.currentToolsVersion
        }
        return try load(file: file, fileSystem: fileSystem)
    }

    func load(file: AbsolutePath, fileSystem: FileSystem) throws -> ToolsVersion {
        // FIXME: We don't need the entire file, just the first line.
        let contents: ByteString
        do { contents = try fileSystem.readFileContents(file) } catch {
            throw Error.inaccessibleManifest(path: file, reason: String(describing: error))
        }

        // Get the version specifier string from tools version file.
        guard let versionSpecifier = ToolsVersionLoader.split(contents).versionSpecifier else {
            // Try to diagnose if there is a misspelling of the swift-tools-version comment.
            let splitted = contents.contents.split(
                separator: UInt8(ascii: "\n"),
                maxSplits: 1,
                omittingEmptySubsequences: false)
            let misspellings = ["swift-tool", "tool-version"]
            if let firstLine = ByteString(splitted[0]).validDescription,
               misspellings.first(where: firstLine.lowercased().contains) != nil {
                throw Error.malformedToolsVersion(specifier: firstLine, currentToolsVersion: currentToolsVersion)
            }
            // Otherwise assume the default to be v3.
            return .v3
        }

        // Ensure we can construct the version from the specifier.
        guard let version = ToolsVersion(string: versionSpecifier) else {
            throw Error.malformedToolsVersion(specifier: versionSpecifier, currentToolsVersion: currentToolsVersion)
        }
        return version
    }

    /// Splits the bytes to the version specifier (if present) and rest of the contents.
    public static func split(_ bytes: ByteString) -> (versionSpecifier: String?, rest: [UInt8]) {
        let splitted = bytes.contents.split(
            separator: UInt8(ascii: "\n"),
            maxSplits: 1,
            omittingEmptySubsequences: false)
        // Try to match our regex and see if a valid specifier line.
        guard let firstLine = ByteString(splitted[0]).validDescription,
              let match = ToolsVersionLoader.regex.firstMatch(
                  in: firstLine, options: [], range: NSRange(location: 0, length: firstLine.count)),
              match.numberOfRanges >= 2 else {
            return (nil, bytes.contents)
        }
        let versionSpecifier = NSString(string: firstLine).substring(with: match.range(at: 1))
        // FIXME: We can probably optimize here and return array slice.
        return (versionSpecifier, splitted.count == 1 ? [] : Array(splitted[1]))
    }

    // The regex to match swift tools version specification:
    // * It should start with `//` followed by any amount of whitespace.
    // * Following that it should contain the case insensitive string `swift-tools-version:`.
    // * The text between the above string and `;` or string end becomes the tools version specifier.
    static let regex = try! NSRegularExpression(
        pattern: "^// swift-tools-version:(.*?)(?:;.*|$)",
        options: [.caseInsensitive])
}
