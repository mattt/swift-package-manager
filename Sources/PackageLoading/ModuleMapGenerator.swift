/*
 This source file is part of the Swift.org open source project
 
 Copyright (c) 2014 - 2020 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception
 
 See http://swift.org/LICENSE.txt for license information
 See http://swift.org/CONTRIBUTORS.txt for Swift project authors
 */

import TSCBasic
import PackageModel
import Foundation

/// Name of the module map file recognized by the Clang and Swift compilers.
public let moduleMapFilename = "module.modulemap"

/// A protocol for targets which might have a modulemap.
protocol ModuleMapProtocol {
    var moduleMapPath: AbsolutePath { get }

    var moduleMapDirectory: AbsolutePath { get }
}

/// A module map generator for Clang targets.  Module map generation consists of two steps:
/// 1. Examining a target's public-headers directory to determine the appropriate module map type
/// 2. Generating a module map for any target that doesn't have a custom module map file
///
/// When a custom module map exists in the header directory, it is used as-is.  When a custom module map does not exist, a module map is generated based on the following rules:
///
/// *  If "include/foo/foo.h" exists and `foo` is the only directory under the "include" directory, and the "include" directory contains no header files:
///    Generates: `umbrella header "/path/to/include/foo/foo.h"`
/// *  If "include/foo.h" exists and "include" contains no other subdirectory:
///    Generates: `umbrella header "/path/to/include/foo.h"`
/// *  Otherwise, if the "include" directory only contains header files and no other subdirectory:
///    Generates: `umbrella "path/to/include"`
///
/// These rules are documented at https://github.com/apple/swift-package-manager/blob/master/Documentation/Usage.md#creating-c-language-targets.  To avoid breaking existing packages, do not change the semantics here without making any change conditional on the tools version of the package that defines the target.
///
/// Note that a module map generator doesn't require a target to already have been instantiated; it can operate on information that will later be used to instantiate a target.
public struct ModuleMapGenerator {
    
    /// The name of the Clang target (for diagnostics).
    private let targetName: String
    
    /// The module name of the target.
    private let moduleName: String
    
    /// The target's public-headers directory.
    private let publicHeadersDir: AbsolutePath
    
    /// The file system to be used.
    private let fileSystem: FileSystem
    
    public init(targetName: String, moduleName: String, publicHeadersDir: AbsolutePath, fileSystem: FileSystem) {
        self.targetName = targetName
        self.moduleName = moduleName
        self.publicHeadersDir = publicHeadersDir
        self.fileSystem = fileSystem
    }
    
    /// Inspects the file system at the public-headers directory with which the module map generator was instantiated, and returns the type of module map that applies to that directory.  This function contains all of the heuristics that implement module map policy for package targets; other functions just use the results of this determination.
    public func determineModuleMapType(diagnostics: DiagnosticsEngine) -> ModuleMapType {
        // The following rules are documented at https://github.com/apple/swift-package-manager/blob/master/Documentation/Usage.md#creating-c-language-targets.  To avoid breaking existing packages, do not change the semantics here without making any change conditional on the tools version of the package that defines the target.
        
        // First check for a custom module map.
        let customModuleMapFile = publicHeadersDir.appending(component: moduleMapFilename)
        if fileSystem.isFile(customModuleMapFile) {
            return .custom(customModuleMapFile)
        }
        
        // Warn if the public-headers directory is missing.  For backward compatibility reasons, this is not an error, we just won't generate a module map in that case.
        guard fileSystem.exists(publicHeadersDir) else {
            diagnostics.emit(.missingPublicHeadersDirectory(targetName: targetName, publicHeadersDir: publicHeadersDir))
            return .none
        }

        // Next try to get the entries in the public-headers directory.
        let entries: Set<AbsolutePath>
        do {
            entries = try Set(fileSystem.getDirectoryContents(publicHeadersDir).map({ publicHeadersDir.appending(component: $0) }))
        }
        catch {
            // This might fail because of a file system error, etc.
            diagnostics.emit(.inaccessiblePublicHeadersDirectory(targetName: targetName, publicHeadersDir: publicHeadersDir, fileSystemError: error))
            return .none
        }
        
        // Filter out headers and directories at the top level of the public-headers directory.
        // FIXME: What about .hh files, or .hpp, etc?  We should centralize the detection of file types based on names (and ideally share with SwiftDriver).
        let headers = entries.filter({ fileSystem.isFile($0) && $0.suffix == ".h" })
        let directories = entries.filter({ fileSystem.isDirectory($0) })
        
        // If 'PublicHeadersDir/ModuleName.h' exists, then use it as the umbrella header.
        let umbrellaHeader = publicHeadersDir.appending(component: moduleName + ".h")
        if fileSystem.isFile(umbrellaHeader) {
            // In this case, 'PublicHeadersDir' is expected to contain no subdirectories.
            if directories.count != 0 {
                diagnostics.emit(.umbrellaHeaderHasSiblingDirectories(targetName: targetName, umbrellaHeader: umbrellaHeader, siblingDirs: directories))
                return .none
            }
            return .umbrellaHeader(umbrellaHeader)
        }

        /// Check for the common mistake of naming the umbrella header 'TargetName.h' instead of 'ModuleName.h'.
        let misnamedUmbrellaHeader = publicHeadersDir.appending(component: targetName + ".h")
        if fileSystem.isFile(misnamedUmbrellaHeader) {
            diagnostics.emit(.misnamedUmbrellaHeader(misnamedUmbrellaHeader: misnamedUmbrellaHeader, umbrellaHeader: umbrellaHeader))
        }

        // If 'PublicHeadersDir/ModuleName/ModuleName.h' exists, then use it as the umbrella header.
        let nestedUmbrellaHeader = publicHeadersDir.appending(components: moduleName, moduleName + ".h")
        if fileSystem.isFile(nestedUmbrellaHeader) {
            // In this case, 'PublicHeadersDir' is expected to contain no subdirectories other than 'ModuleName'.
            if directories.count != 1 {
                diagnostics.emit(.umbrellaHeaderParentDirHasSiblingDirectories(targetName: targetName, umbrellaHeader: nestedUmbrellaHeader, siblingDirs: directories.filter{ $0.basename != moduleName }))
                return .none
            }
            // In this case, 'PublicHeadersDir' is also expected to contain no header files.
            if headers.count != 0 {
                diagnostics.emit(.umbrellaHeaderParentDirHasSiblingHeaders(targetName: targetName, umbrellaHeader: nestedUmbrellaHeader, siblingHeaders: headers))
                return .none
            }
            return .umbrellaHeader(nestedUmbrellaHeader)
        }
        
        /// Check for the common mistake of naming the nested umbrella header 'TargetName.h' instead of 'ModuleName.h'.
        let misnamedNestedUmbrellaHeader = publicHeadersDir.appending(components: moduleName, targetName + ".h")
        if fileSystem.isFile(misnamedNestedUmbrellaHeader) {
            diagnostics.emit(.misnamedUmbrellaHeader(misnamedUmbrellaHeader: misnamedNestedUmbrellaHeader, umbrellaHeader: nestedUmbrellaHeader))
        }

        // Otherwise, if 'PublicHeadersDir' contains only header files and no subdirectories, use it as the umbrella directory.
        if headers.count == entries.count {
            return .umbrellaDirectory(publicHeadersDir)
        }
        
        // Otherwise, the target's public headers are considered to be incompatible with modules.  Per the original design, though, an umbrella directory is still created for them.  This will lead to build failures if those headers are included and they are not compatible with modules.  A future evolution proposal should revisit these semantics, especially to make it easier to existing wrap C source bases that are incompatible with modules.
        return .umbrellaDirectory(publicHeadersDir)
    }
    
    /// Generates a module map based of the specified type, throwing an error if anything goes wrong.  Any diagnostics are added to the receiver's diagnostics engine.
    public func generateModuleMap(type: GeneratedModuleMapType, at path: AbsolutePath) throws {
        let stream = BufferedOutputByteStream()
        stream <<< "module \(moduleName) {\n"
        switch type {
        case .umbrellaHeader(let hdr):
            stream <<< "    umbrella header \"\(hdr.moduleEscapedPathString)\"\n"
        case .umbrellaDirectory(let dir):
            stream <<< "    umbrella \"\(dir.moduleEscapedPathString)\"\n"
        }
        stream <<< "    export *\n"
        stream <<< "}\n"

        // FIXME: This doesn't belong here.
        try fileSystem.createDirectory(path.parentDirectory, recursive: true)

        // If the file exists with the identical contents, we don't need to rewrite it.
        // Otherwise, compiler will recompile even if nothing else has changed.
        if let contents = try? fileSystem.readFileContents(path), contents == stream.bytes {
            return
        }
        try fileSystem.writeFileContents(path, bytes: stream.bytes)
    }
}

/// A type of module map to generate.
public enum GeneratedModuleMapType {
    case umbrellaHeader(AbsolutePath)
    case umbrellaDirectory(AbsolutePath)
}

fileprivate extension AbsolutePath {
    var moduleEscapedPathString: String {
        return self.pathString.replacingOccurrences(of: "\\", with: "\\\\")
    }
}
