/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2014 - 2017 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See http://swift.org/LICENSE.txt for license information
 See http://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import TSCBasic
import TSCUtility
import PackageModel

extension Diagnostic.Message {
    static func targetHasNoSources(targetPath: String, target: String) -> Diagnostic.Message {
        .warning("Source files for target \(target) should be located under \(targetPath)")
    }

    static func manifestLoading(output: String, diagnosticFile: AbsolutePath?) -> Diagnostic.Message {
        .warning(ManifestLoadingDiagnostic(output: output, diagnosticFile: diagnosticFile))
    }

    static func targetNameHasIncorrectCase(target: String) -> Diagnostic.Message {
        .warning("the target name \(target) has different case on the filesystem and the Package.swift manifest file")
    }

    static func unsupportedCTestTarget(package: String, target: String) -> Diagnostic.Message {
        .warning("ignoring target '\(target)' in package '\(package)'; C language in tests is not yet supported")
    }

    static func duplicateProduct(product: Product) -> Diagnostic.Message {
        let typeString: String
        switch product.type {
        case .library(.automatic):
            typeString = ""
        case .executable, .test,
             .library(.dynamic), .library(.static):
            typeString = " (\(product.type))"
        }

        return .warning("ignoring duplicate product '\(product.name)'\(typeString)")
    }

    static func duplicateTargetDependency(dependency: String, target: String) -> Diagnostic.Message {
        .warning("invalid duplicate target dependency declaration '\(dependency)' in target '\(target)'")
    }

    static var systemPackageDeprecation: Diagnostic.Message {
        .warning("system packages are deprecated; use system library targets instead")
    }

    static func systemPackageDeclaresTargets(targets: [String]) -> Diagnostic.Message {
        .warning("ignoring declared target(s) '\(targets.joined(separator: ", "))' in the system package")
    }

    static func systemPackageProductValidation(product: String) -> Diagnostic.Message {
        .error("system library product \(product) shouldn't have a type and contain only one target")
    }

    static func executableProductTargetNotExecutable(product: String, target: String) -> Diagnostic.Message {
        .error("""
            executable product '\(product)' expects target '\(target)' to be executable; an executable target requires \
            a 'main.swift' file
            """)
    }

    static func executableProductWithoutExecutableTarget(product: String) -> Diagnostic.Message {
        .error("""
            executable product '\(product)' should have one executable target; an executable target requires a \
            'main.swift' file
            """)
    }

    static func executableProductWithMoreThanOneExecutableTarget(product: String) -> Diagnostic.Message {
        .error("executable product '\(product)' should not have more than one executable target")
    }

    static var noLibraryTargetsForREPL: Diagnostic.Message {
        .error("unable to synthesize a REPL product as there are no library targets in the package")
    }

    static func brokenSymlink(_ path: AbsolutePath) -> Diagnostic.Message {
        .warning("ignoring broken symlink \(path)")
    }

    static func conflictingResource(path: RelativePath, targetName: String) -> Self {
        .error("multiple resources named '\(path)' in target '\(targetName)'")
    }

    static func fileReference(path: RelativePath) -> Self {
        .note("found '\(path)'")
    }

    static func infoPlistResourceConflict(
        path: RelativePath,
        targetName: String
    ) -> Self {
        .error("""
            resource '\(path)' in target '\(targetName)' is forbidden; Info.plist is not supported as a top-level \
            resource file in the resources bundle
            """)
    }

    static func copyConflictWithLocalizationDirectory(path: RelativePath, targetName: String) -> Self {
        .error("resource '\(path)' in target '\(targetName)' conflicts with other localization directories")
    }

    static func missingDefaultLocalization() -> Self {
        .error("missing manifest property 'defaultLocalization'; it is required in the presence of localized resources")
    }

    static func localizationAmbiguity(path: RelativePath, targetName: String) -> Self {
        .error("""
            resource '\(path)' in target '\(targetName)' is in a localization directory and has an explicit \
            localization declaration in the package manifest; choose one or the other to avoid any ambiguity
            """)
    }

    static func localizedAndUnlocalizedVariants(resource: String, targetName: String) -> Self {
        .warning("""
            resource '\(resource)' in target '\(targetName)' has both localized and un-localized variants; the \
            localized variants will never be chosen
            """)
    }

    static func missingDefaultLocalizationResource(
        resource: String,
        targetName: String,
        defaultLocalization: String
    ) -> Self {
        .warning("""
            resource '\(resource)' in target '\(targetName)' is missing the default localization \
            '\(defaultLocalization)'; the default localization is used as a fallback when no other localization matches
            """)
    }

    static func duplicateTargetName(targetName: String) -> Self {
        .error("duplicate target named '\(targetName)'")
    }

    static func emptyProductTargets(productName: String) -> Self {
        .error("product '\(productName)' doesn't reference any targets")
    }

    static func productTargetNotFound(productName: String, targetName: String) -> Self {
        .error("target '\(targetName)' referenced in product '\(productName)' could not be found")
    }

    static func invalidBinaryProductType(productName: String) -> Self {
        .error("invalid type for binary product '\(productName)'; products referencing only binary targets must have a type of 'library'")
    }

    static func duplicateDependency(dependencyIdentity: String) -> Self {
        .error("duplicate dependency '\(dependencyIdentity)'")
    }

    static func duplicateDependencyName(dependencyName: String) -> Self {
        .error("duplicate dependency named '\(dependencyName)'; consider differentiating them using the 'name' argument")
    }

    static func unknownTargetDependency(dependency: String, targetName: String) -> Self {
        .error("unknown dependency '\(dependency)' in target '\(targetName)'")
    }

    static func unknownTargetPackageDependency(packageName: String, targetName: String) -> Self {
        .error("unknown package '\(packageName)' in dependencies of target '\(targetName)'")
    }

    static func invalidBinaryLocation(targetName: String) -> Self {
        .error("invalid location for binary target '\(targetName)'")
    }

    static func invalidBinaryURLScheme(targetName: String, validSchemes: [String]) -> Self {
        .error("invalid URL scheme for binary target '\(targetName)'; valid schemes are: \(validSchemes.joined(separator: ", "))")
    }

    static func unsupportedBinaryLocationExtension(targetName: String, validExtensions: [String]) -> Self {
        .error("unsupported extension for binary target '\(targetName)'; valid extensions are: \(validExtensions.joined(separator: ", "))")
    }

    static func invalidLanguageTag(_ languageTag: String) -> Self {
        .error("""
            invalid language tag '\(languageTag)'; the pattern for language tags is groups of latin characters and \
            digits separated by hyphens
            """)
    }

    static func symlinkInSources(symlink: RelativePath, targetName: String) -> Self {
        .warning("ignoring symlink at '\(symlink)' in target '\(targetName)'")
    }

    static func localizationDirectoryContainsSubDirectories(
        localizationDirectory: RelativePath,
        targetName: String
    ) -> Self {
        .error("localization directory '\(localizationDirectory)' in target '\(targetName)' contains sub-directories, which is forbidden")
    }
}

public struct ManifestLoadingDiagnostic: DiagnosticData {
    public let output: String
    public let diagnosticFile: AbsolutePath?

    public var description: String { output }
}

public struct PkgConfigDiagnosticLocation: DiagnosticLocation {
    public let pcFile: String
    public let target: String

    public init(pcFile: String, target: String) {
        self.pcFile = pcFile
        self.target = target
    }

    public var description: String {
        return "'\(target)' \(pcFile).pc"
    }
}

// FIXME: Kill this.
public struct PkgConfigGenericDiagnostic: DiagnosticData {
    public let error: String

    public init(error: String) {
        self.error = error
    }

    public var description: String {
        return error
    }
}

// FIXME: Kill this.
public struct PkgConfigHintDiagnostic: DiagnosticData {
    public let pkgConfigName: String
    public let installText: String

    public init(pkgConfigName: String, installText: String) {
        self.pkgConfigName = pkgConfigName
        self.installText = installText
    }

    public var description: String {
        return "you may be able to install \(pkgConfigName) using your system-packager:\n\(installText)"
    }
}

