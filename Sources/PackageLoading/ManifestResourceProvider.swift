/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2014 - 2020 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See http://swift.org/LICENSE.txt for license information
 See http://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import TSCBasic
import PackageModel
import TSCUtility
import Foundation

/// Resources required for manifest loading.
///
/// These requirements are abstracted out to make it easier to add support for
/// using the package manager with alternate toolchains in the future.
public protocol ManifestResourceProvider {
    /// The path of the swift compiler.
    var swiftCompiler: AbsolutePath { get }

    /// The path of the library resources.
    var libDir: AbsolutePath { get }

    /// The path to SDK root.
    ///
    /// If provided, it will be passed to the swift interpreter.
    var sdkRoot: AbsolutePath? { get }

    /// The bin directory.
    var binDir: AbsolutePath? { get }

    /// Extra flags to pass the Swift compiler.
    var swiftCompilerFlags: [String] { get }

    /// XCTest Location
    var xctestLocation: AbsolutePath? { get }
}

/// Default implemention for the resource provider.
public extension ManifestResourceProvider {

    var sdkRoot: AbsolutePath? {
        return nil
    }

    var binDir: AbsolutePath? {
        return nil
    }

    var swiftCompilerFlags: [String] {
        return []
    }

    var xctestLocation: AbsolutePath? {
        return nil
    }
}
