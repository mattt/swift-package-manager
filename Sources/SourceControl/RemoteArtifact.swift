/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2014 - 2020 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See http://swift.org/LICENSE.txt for license information
 See http://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import TSCBasic

/// A structure representing the remote artifact information necessary to construct the package.
public struct RemoteArtifact {

    /// The URL the artifact was downloaded from.
    public let url: String

    /// The path to the downloaded artifact.
    public let path: AbsolutePath

    public init(url: String, path: AbsolutePath) {
        self.url = url
        self.path = path
    }
}
