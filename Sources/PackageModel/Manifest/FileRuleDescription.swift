/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2014 - 2020 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See http://swift.org/LICENSE.txt for license information
 See http://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import TSCBasic

/// Describes a rule for including a source or resource file in a target.
public struct FileRuleDescription {
    /// A rule semantically describes a file/directory in a target.
    ///
    /// It is up to the build system to translate a rule into a build command.
    public enum Rule {
        /// The compile rule for `sources` in a package.
        case compile

        /// Process resource file rule for any type of platform-specific processing.
        ///
        /// This defaults to copy if there's no specialized behavior.
        case processResource

        /// The copy rule.
        case copy

        /// The modulemap rule.
        case modulemap

        /// A header file.
        case header

        /// Sentinal to indicate that no rule was chosen for a given file.
        case none
    }

    /// The rule associated with this description.
    public let rule: Rule

    /// The tools version supported by this rule.
    public let toolsVersion: ToolsVersion

    /// The list of file extensions support by this rule.
    ///
    /// No two rule can have the same file extension.
    public let fileTypes: Set<String>

    public init(rule: Rule, toolsVersion: ToolsVersion, fileTypes: Set<String>) {
        self.rule = rule
        self.toolsVersion = toolsVersion
        self.fileTypes = fileTypes
    }

    /// Match the given path to the rule.
    public func match(path: AbsolutePath, toolsVersion: ToolsVersion) -> Bool {
        if toolsVersion < self.toolsVersion {
            return false
        }

        if let ext = path.extension {
            return self.fileTypes.contains(ext)
        }
        return false
    }

    /// The swift compiler rule.
    public static let swift: FileRuleDescription = {
        .init(
            rule: .compile,
            toolsVersion: .minimumRequired,
            fileTypes: ["swift"]
        )
    }()

    /// The clang compiler rule.
    public static let clang: FileRuleDescription = {
        .init(
            rule: .compile,
            toolsVersion: .minimumRequired,
            fileTypes: ["c", "m", "mm", "cc", "cpp", "cxx"]
        )
    }()

    /// The rule for compiling asm files.
    public static let asm: FileRuleDescription = {
        .init(
            rule: .compile,
            toolsVersion: .v5,
            fileTypes: ["s", "S"]
        )
    }()

    /// The rule for detecting modulemap files.
    public static let modulemap: FileRuleDescription = {
        .init(
            rule: .modulemap,
            toolsVersion: .minimumRequired,
            fileTypes: ["modulemap"]
        )
    }()

    /// The rule for detecting header files.
    public static let header: FileRuleDescription = {
        .init(
            rule: .header,
            toolsVersion: .minimumRequired,
            fileTypes: ["h", "hh", "hpp", "h++", "hp", "hxx", "H", "ipp", "def"]
        )
    }()

    /// File types related to the interface builder and storyboards.
    public static let xib: FileRuleDescription = {
        .init(
            rule: .processResource,
            toolsVersion: .v5_3,
            fileTypes: ["nib", "xib", "storyboard"]
        )
    }()

    /// File types related to the asset catalog.
    public static let assetCatalog: FileRuleDescription = {
        .init(
            rule: .processResource,
            toolsVersion: .v5_3,
            fileTypes: ["xcassets"]
        )
    }()

    /// File types related to the CoreData.
    public static let coredata: FileRuleDescription = {
        .init(
            rule: .processResource,
            toolsVersion: .v5_3,
            fileTypes: ["xcdatamodeld", "xcdatamodel", "xcmappingmodel"]
        )
    }()

    /// File types related to Metal.
    public static let metal: FileRuleDescription = {
        .init(
            rule: .processResource,
            toolsVersion: .v5_3,
            fileTypes: ["metal"]
        )
    }()

    /// List of all the builtin rules.
    public static let builtinRules: [FileRuleDescription] = [
        swift,
        clang,
        asm,
        modulemap,
        header,
    ] + xcbuildFileTypes

    /// List of file types that requires the Xcode build system.
    public static let xcbuildFileTypes: [FileRuleDescription] = [
        xib,
        assetCatalog,
        coredata,
        metal,
    ]
}
