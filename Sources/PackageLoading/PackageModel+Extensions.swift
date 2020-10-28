/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2014 - 2020 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See http://swift.org/LICENSE.txt for license information
 See http://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import TSCBasic
import TSCUtility

import PackageModel

extension Manifest {
    /// Returns the manifest at the given package path.
    ///
    /// Version specific manifest is chosen if present, otherwise path to regular
    /// manfiest is returned.
    public static func path(
        atPackagePath packagePath: AbsolutePath,
        currentToolsVersion: ToolsVersion = .currentToolsVersion,
        fileSystem: FileSystem
    ) throws -> AbsolutePath {
        // Look for a version-specific manifest.
        for versionSpecificKey in Versioning.currentVersionSpecificKeys {
            let versionSpecificPath = packagePath.appending(component: Manifest.basename + versionSpecificKey + ".swift")
            if fileSystem.isFile(versionSpecificPath) {
                return versionSpecificPath
            }
        }

        // Otherwise, check if there is a version-specific manifest that has
        // a higher tools version than the main Package.swift file.
        let contents: [String]
        do { contents = try fileSystem.getDirectoryContents(packagePath) } catch {
            throw ToolsVersionLoader.Error.inaccessiblePackage(path: packagePath, reason: String(describing: error))
        }
        let regex = try! RegEx(pattern: "^Package@swift-(\\d+)(?:\\.(\\d+))?(?:\\.(\\d+))?.swift$")

        // Collect all version-specific manifests at the given package path.
        let versionSpecificManifests = Dictionary(contents.compactMap{ file -> (ToolsVersion, String)? in
            let parsedVersion = regex.matchGroups(in: file)
            guard parsedVersion.count == 1, parsedVersion[0].count == 3 else {
                return nil
            }

            let major = Int(parsedVersion[0][0])!
            let minor = parsedVersion[0][1].isEmpty ? 0 : Int(parsedVersion[0][1])!
            let patch = parsedVersion[0][2].isEmpty ? 0 : Int(parsedVersion[0][2])!

            return (ToolsVersion(version: Version(major, minor, patch)), file)
        }, uniquingKeysWith: { $1 })

        let regularManifest = packagePath.appending(component: filename)
        let toolsVersionLoader = ToolsVersionLoader(currentToolsVersion: currentToolsVersion)

        // Find the version-specific manifest that statisfies the current tools version.
        if let versionSpecificCandidate = versionSpecificManifests.keys.sorted(by: >).first(where: { $0 <= currentToolsVersion }) {
            let versionSpecificManifest = packagePath.appending(component: versionSpecificManifests[versionSpecificCandidate]!)

            // Compare the tools version of this manifest with the regular
            // manifest and use the version-specific manifest if it has
            // a greater tools version.
            let versionSpecificManifestToolsVersion = try toolsVersionLoader.load(file: versionSpecificManifest, fileSystem: fileSystem)
            let regularManifestToolsVersion = try toolsVersionLoader.load(file: regularManifest, fileSystem: fileSystem)
            if versionSpecificManifestToolsVersion > regularManifestToolsVersion {
                return versionSpecificManifest
            }
        }

        return regularManifest
    }
}

// MARK: -

extension Package {
    /// An error in the structure or layout of a package.
    public enum Error: Swift.Error {
        /// Describes a way in which a package layout is invalid.
        public enum InvalidLayoutType {
            case multipleSourceRoots([AbsolutePath])
            case modulemapInSources(AbsolutePath)
            case modulemapMissing(AbsolutePath)
        }

        /// The package has no Package.swift file
        case noManifest(baseURL: String, version: String?)

        /// Indicates two targets with the same name and their corresponding packages.
        case duplicateModule(String, [String])

        /// The referenced target could not be found.
        case moduleNotFound(String, TargetDescription.TargetType)

        /// The artifact for the binary target could not be found.
        case artifactNotFound(String)

        /// Invalid custom path.
        case invalidCustomPath(target: String, path: String)

        /// Package layout is invalid.
        case invalidLayout(InvalidLayoutType)

        /// The manifest has invalid configuration wrt type of the target.
        case invalidManifestConfig(String, String)

        /// The target dependency declaration has cycle in it.
        case cycleDetected((path: [String], cycle: [String]))

        /// The public headers directory is at an invalid path.
        case invalidPublicHeadersDirectory(String)

        /// The sources of a target are overlapping with another target.
        case overlappingSources(target: String, sources: [AbsolutePath])

        /// We found multiple LinuxMain.swift files.
        case multipleLinuxMainFound(package: String, linuxMainFiles: [AbsolutePath])

        /// The tools version in use is not compatible with target's sources.
        case incompatibleToolsVersions(package: String, required: [SwiftLanguageVersion], current: ToolsVersion)

        /// The target path is outside the package.
        case targetOutsidePackage(package: String, target: String)

        /// Unsupported target path
        case unsupportedTargetPath(String)

        /// Invalid header search path.
        case invalidHeaderSearchPath(String)

        /// Default localization not set in the presence of localized resources.
        case defaultLocalizationNotSet
    }
}

extension Package.Error: CustomStringConvertible {
    public var description: String {
        switch self {
        case .noManifest(let baseURL, let version):
            var string = "\(baseURL) has no Package.swift manifest"
            if let version = version {
                string += " for version \(version)"
            }
            return string
        case .duplicateModule(let name, let packages):
            let packages = packages.joined(separator: ", ")
            return "multiple targets named '\(name)' in: \(packages)"
        case .moduleNotFound(let target, let type):
            let folderName = type == .test ? "Tests" : "Sources"
            return "Source files for target \(target) should be located under '\(folderName)/\(target)', or a custom sources path can be set with the 'path' property in Package.swift"
        case .artifactNotFound(let target):
            return "artifact not found for target '\(target)'"
        case .invalidLayout(let type):
            return "package has unsupported layout; \(type)"
        case .invalidManifestConfig(let package, let message):
            return "configuration of package '\(package)' is invalid; \(message)"
        case .cycleDetected(let cycle):
            return "cyclic dependency declaration found: " +
                (cycle.path + cycle.cycle).joined(separator: " -> ") +
                " -> " + cycle.cycle[0]
        case .invalidPublicHeadersDirectory(let name):
            return "public headers directory path for '\(name)' is invalid or not contained in the target"
        case .overlappingSources(let target, let sources):
            return "target '\(target)' has sources overlapping sources: " +
                sources.map({ $0.description }).joined(separator: ", ")
        case .multipleLinuxMainFound(let package, let linuxMainFiles):
            return "package '\(package)' has multiple linux main files: " +
                linuxMainFiles.map({ $0.description }).sorted().joined(separator: ", ")
        case .incompatibleToolsVersions(let package, let required, let current):
            if required.isEmpty {
                return "package '\(package)' supported Swift language versions is empty"
            }
            return "package '\(package)' requires minimum Swift language version \(required[0]) which is not supported by the current tools version (\(current))"
        case .targetOutsidePackage(let package, let target):
            return "target '\(target)' in package '\(package)' is outside the package root"
        case .unsupportedTargetPath(let targetPath):
            return "target path '\(targetPath)' is not supported; it should be relative to package root"
        case .invalidCustomPath(let target, let path):
            return "invalid custom path '\(path)' for target '\(target)'"
        case .invalidHeaderSearchPath(let path):
            return "invalid header search path '\(path)'; header search path should not be outside the package root"
        case .defaultLocalizationNotSet:
            return "manifest property 'defaultLocalization' not set; it is required in the presence of localized resources"
        }
    }
}

extension Package.Error.InvalidLayoutType: CustomStringConvertible {
    public var description: String {
        switch self {
        case .multipleSourceRoots(let paths):
          return "multiple source roots found: " + paths.map({ $0.description }).sorted().joined(separator: ", ")
        case .modulemapInSources(let path):
            return "modulemap '\(path)' should be inside the 'include' directory"
        case .modulemapMissing(let path):
            return "missing system target module map at '\(path)'"
        }
    }
}

// MARK: -

extension Target {
    /// An error in the organization or configuration of an individual target.
    public enum Error: Swift.Error {
        /// The target's name is invalid.
        case invalidName(path: RelativePath, problem: ModuleNameProblem)
        public enum ModuleNameProblem {
            /// Empty target name.
            case emptyName
        }

        /// The target contains an invalid mix of languages (e.g. both Swift and C).
        case mixedSources(AbsolutePath)
    }
}

extension Target.Error: CustomStringConvertible {
    public var description: String {
        switch self {
        case .invalidName(let path, let problem):
            return "invalid target name at '\(path)'; \(problem)"
        case .mixedSources(let path):
            return "target at '\(path)' contains mixed language source files; feature not supported"
        }
    }
}

extension Target.Error.ModuleNameProblem: CustomStringConvertible {
    public var description: String {
        switch self {
          case .emptyName:
            return "target names can not be empty"
        }
    }
}

// MARK: -

extension SystemLibraryTarget: ModuleMapProtocol {
    var moduleMapDirectory: AbsolutePath {
        return path
    }

    public var moduleMapPath: AbsolutePath {
        return moduleMapDirectory.appending(component: moduleMapFilename)
    }
}

extension ClangTarget: ModuleMapProtocol {
    var moduleMapDirectory: AbsolutePath {
        return includeDir
    }

    public var moduleMapPath: AbsolutePath {
        return moduleMapDirectory.appending(component: moduleMapFilename)
    }
}

// MARK: -

extension Product {
    /// An error in a product definition.
    public enum Error: Swift.Error {
        case moduleEmpty(product: String, target: String)
    }
}

extension Product.Error: CustomStringConvertible {
    public var description: String {
        switch self {
        case .moduleEmpty(let product, let target):
            return "target '\(target)' referenced in product '\(product)' is empty"
        }
    }
}

// MARK: -

extension ModuleMapType {
    /// Returns the type of module map to generate for this kind of module map, or nil to not generate one at all.
    public var generatedModuleMapType: GeneratedModuleMapType? {
        switch self {
        case .umbrellaHeader(let path): return .umbrellaHeader(path)
        case .umbrellaDirectory(let path): return .umbrellaDirectory(path)
        case .none, .custom(_): return nil
        }
    }
}

// MARK: -

extension Sources {
    var hasSwiftSources: Bool {
        paths.first?.extension == "swift"
    }

    var containsMixedLanguage: Bool {
        let swiftSources = relativePaths.filter{ $0.extension == "swift" }
        if swiftSources.isEmpty { return false }
        return swiftSources.count != relativePaths.count
    }
}
