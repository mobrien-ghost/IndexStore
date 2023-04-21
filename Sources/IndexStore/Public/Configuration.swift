//
//  Configuration.swift
//  IndexStore
//
//  Copyright (c) CheekyGhost Labs 2022. All Rights Reserved.
//

import Foundation
import TSCBasic

/// Struct holding configuration values that can override any resolvable defaults.
public struct Configuration: Decodable {

    /// The  root project directory path.
    public let projectDirectory: String

    /// The project index storePath path.
    public let indexStorePath: String

    /// The project index database path.
    public let indexDatabasePath: String

    /// The path to the libIndexStore dlyib.
    public let libIndexStorePath: String

    /// Bool whether to exclude any system symbols from results.
    ///
    /// i.e: `Equatable` is a system symbol and would be excluded from any results.
    public let excludeSystemResults: Bool

    /// Bool whether to exclude any symbols from results where the `isStale` is `true`.
    public let excludeStaleResults: Bool

    // MARK: - Codable

    enum CodingKeys: CodingKey {
        case projectDirectory
        case indexStorePath
        case indexDatabasePath
        case libIndexStorePath
        case excludeSystemResults
        case excludeStaleResults
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.projectDirectory = try container.decode(String.self, forKey: .projectDirectory)
        self.excludeSystemResults = try container.decode(Bool.self, forKey: .excludeSystemResults)
        self.excludeStaleResults = try container.decode(Bool.self, forKey: .excludeStaleResults)
        // Optionals
        let storePath = try container.decodeIfPresent(String.self, forKey: .indexStorePath)
        let databasePath = try container.decodeIfPresent(String.self, forKey: .indexDatabasePath)
        let libIndexPath = try container.decodeIfPresent(String.self, forKey: .libIndexStorePath)
        // Assign using provided as defaults
        indexDatabasePath = Self.resolveIndexDatabasePath(provided: databasePath)
        indexStorePath = try Self.resolveIndexStorePath(provided: storePath)
        libIndexStorePath = try Self.resolveLibIndexStorePath(provided: libIndexPath)
    }

    // MARK: - Lifecycle

    /// Will initialize a new configuration instance with the given details.
    /// - Parameters:
    ///   - projectDirectory: The root project directory the kit will be working in. This is used when looking up symbols by source file path.
    ///   - indexStorePath: The project index store directory path. A default path derived from the build directory will by assigned if left as `nil`.
    ///   - indexDatabasePath: The project index database path. A default path within the temporary directory will be assigned if left as `nil`.
    ///   - libIndexStorePath: The path to the libIndexStore dlyib. `xcode-select -p` command will be used to build the path if left as `nil`.
    ///   - excludeSystemResults: Bool whether to exclude any system symbols from results.
    ///   - excludeStaleResults: Bool whether to exclude any symbols from results where the `isStale` is `true`.
    public init(
        projectDirectory: String,
        indexStorePath: String? = nil,
        indexDatabasePath: String? = nil,
        libIndexStorePath: String? = nil,
        excludeSystemResults: Bool = true,
        excludeStaleResults: Bool = true
    ) throws {
        self.excludeSystemResults = excludeSystemResults
        self.excludeStaleResults = excludeStaleResults
        self.projectDirectory = projectDirectory
        self.indexDatabasePath = Self.resolveIndexDatabasePath(provided: indexDatabasePath)
        self.libIndexStorePath = try Self.resolveLibIndexStorePath(provided: libIndexStorePath)
        self.indexStorePath = try Self.resolveIndexStorePath(provided: indexStorePath)
    }

    // MARK: Defaults Helpers

    /// Will return the provided value if not `nil`, otherwise will return a path within the temporary directory.
    /// - Parameter provided: The provided value to assess.
    /// - Returns: `String`
    static func resolveIndexDatabasePath(provided: String?) -> String {
        if let provided { return provided }
        return "\(NSTemporaryDirectory())index_\(getpid())"
    }

    /// Will return the provided value if not `nil`, otherwise will return the ideal build products value from the provided process info instance.
    /// - Parameter provided: The provided value to assess.
    /// - Returns: `String`
    static func resolveIndexStorePath(provided: String?) throws -> String {
        if let provided { return provided }
        // Resolve index store db path from active process
        let processInfo = ProcessInfo()
        let isXcode = processInfo.environment.keys.contains(EnvironmentKeys.xcodeBuiltProducts)
        return try isXcode ? xcodeIndexStorePath(processInfo: processInfo) : swiftIndexStorePath(processInfo: processInfo)
    }

    /// Will return the ideal xcode build products value from the provided process info instance.
    /// - Parameter processInfo: The current process info.
    /// - Returns: `String`
    static func xcodeIndexStorePath(processInfo: ProcessInfo) throws -> String {
        let buildRoot = try processInfo.environmentVariable(name: EnvironmentKeys.xcodeBuiltProducts)
        let buildRootPath = try AbsolutePath(validating: buildRoot).parentDirectory.parentDirectory.parentDirectory
        return "\(buildRootPath.pathString)/Index.noindex/DataStore"
    }

    /// Will return the ideal value from the provided process info instance.
    /// - Parameter processInfo: The current process info.
    /// - Returns: `String`
    static func swiftIndexStorePath(processInfo: ProcessInfo) throws -> String {
        let projectDirectory = try processInfo.environmentVariable(name: EnvironmentKeys.PWD)
        let buildRoot = projectDirectory + "/.build/debug"
        let buildRootPath = try AbsolutePath(validating: buildRoot)
        return "\(buildRootPath.pathString)/Index/Store"
    }

    /// Will return the provided value if not `nil`, otherwise will run the `xcode-select -p` command to get the xcode path.
    /// - Parameter provided: The provided value to assess
    /// - Returns: `String`
    static func resolveLibIndexStorePath(provided: String?) throws -> String {
        guard let provided else {
            let path = try shell("xcode-select -p")
            return "\(path)/Toolchains/XcodeDefault.xctoolchain/usr/lib/libIndexStore.dylib"
        }
        return provided
    }
}
