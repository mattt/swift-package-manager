/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2014 - 2020 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See http://swift.org/LICENSE.txt for license information
 See http://swift.org/CONTRIBUTORS.txt for Swift project authors
 */

import Dispatch

import Basics
import PackageLoading
import PackageModel
import SourceControl
import TSCBasic
import TSCUtility

/// Local package container.
///
/// This class represent packages that are referenced locally in the file system.
/// There is no need to perform any git operations on such packages and they
/// should be used as-is. Infact, they might not even have a git repository.
/// Examples: Root packages, local dependencies, edited packages.
public final class LocalPackageContainer: PackageContainer {
    public let package: PackageReference
    private let mirrors: DependencyMirrors
    private let manifestLoader: ManifestLoaderProtocol
    private let toolsVersionLoader: ToolsVersionLoaderProtocol
    private let currentToolsVersion: ToolsVersion

    /// The file system that shoud be used to load this package.
    private let fileSystem: FileSystem

    /// cached version of the manifest
    private let manifest = ThreadSafeBox<Manifest>()

    private func loadManifest() throws -> Manifest {
        try manifest.memoize() {
            // Load the tools version.
            let toolsVersion = try toolsVersionLoader.load(at: AbsolutePath(package.location), fileSystem: fileSystem)

            // Validate the tools version.
            try toolsVersion.validateToolsVersion(self.currentToolsVersion, packagePath: package.location)

            // Load the manifest.
            // FIXME: this should not block
            return try temp_await {
                manifestLoader.load(package: AbsolutePath(package.location),
                                    baseURL: package.location,
                                    version: nil,
                                    toolsVersion: toolsVersion,
                                    packageKind: package.kind,
                                    fileSystem: fileSystem,
                                    on: .global(),
                                    completion: $0)
            }
        }
    }

    public func getUnversionedDependencies(productFilter: ProductFilter) throws -> [PackageContainerConstraint] {
        return try loadManifest().dependencyConstraints(productFilter: productFilter, mirrors: mirrors)
    }

    public func getUpdatedIdentifier(at boundVersion: BoundVersion) throws -> PackageReference {
        assert(boundVersion == .unversioned, "Unexpected bound version \(boundVersion)")
        let manifest = try loadManifest()
        return package.with(newName: manifest.name)
    }

    public init(
        package: PackageReference,
        mirrors: DependencyMirrors,
        manifestLoader: ManifestLoaderProtocol,
        toolsVersionLoader: ToolsVersionLoaderProtocol,
        currentToolsVersion: ToolsVersion,
        fileSystem: FileSystem = localFileSystem
    ) {
        assert(URL.scheme(package.location) == nil, "unexpected scheme \(URL.scheme(package.location)!) in \(package.location)")
        self.package = package
        self.mirrors = mirrors
        self.manifestLoader = manifestLoader
        self.toolsVersionLoader = toolsVersionLoader
        self.currentToolsVersion = currentToolsVersion
        self.fileSystem = fileSystem
    }

    public func isToolsVersionCompatible(at version: Version) -> Bool {
        fatalError("This should never be called")
    }

    public func toolsVersion(for version: Version) throws -> ToolsVersion {
        fatalError("This should never be called")
    }

    public func toolsVersionsAppropriateVersionsDescending() throws -> [Version] {
        fatalError("This should never be called")
    }

    public func versionsAscending() throws -> [Version] {
        fatalError("This should never be called")
    }

    public func getDependencies(at version: Version, productFilter: ProductFilter) throws -> [PackageContainerConstraint] {
        fatalError("This should never be called")
    }

    public func getDependencies(at revision: String, productFilter: ProductFilter) throws -> [PackageContainerConstraint] {
        fatalError("This should never be called")
    }
}

extension LocalPackageContainer: CustomStringConvertible  {
    public var description: String {
        return "LocalPackageContainer(\(package.location))"
    }
}

public class LocalPackageContainerProvider: PackageContainerProvider {
    let manifestLoader: ManifestLoaderProtocol
    let mirrors: DependencyMirrors

    /// The tools version currently in use. Only the container versions less than and equal to this will be provided by
    /// the container.
    let currentToolsVersion: ToolsVersion

    /// The tools version loader.
    let toolsVersionLoader: ToolsVersionLoaderProtocol

    let fileSystem: FileSystem

    public init(
        mirrors: DependencyMirrors = DependencyMirrors(),
        manifestLoader: ManifestLoaderProtocol,
        currentToolsVersion: ToolsVersion = ToolsVersion.currentToolsVersion,
        toolsVersionLoader: ToolsVersionLoaderProtocol = ToolsVersionLoader(),
        fileSystem: FileSystem = localFileSystem
    ) {
        self.mirrors = mirrors
        self.manifestLoader = manifestLoader
        self.currentToolsVersion = currentToolsVersion
        self.toolsVersionLoader = toolsVersionLoader
        self.fileSystem = fileSystem
    }

    public func getContainer(
        for identifier: PackageReference,
        skipUpdate: Bool,
        on queue: DispatchQueue,
        completion: @escaping (Result<PackageContainer, Swift.Error>) -> Void)
    {
        assert(identifier.kind != .remote)

        let container = LocalPackageContainer(
            package: identifier,
            mirrors: self.mirrors,
            manifestLoader: self.manifestLoader,
            toolsVersionLoader: self.toolsVersionLoader,
            currentToolsVersion: self.currentToolsVersion,
            fileSystem: self.fileSystem
        )

        queue.async {
            completion(.success(container))
        }
    }
}
