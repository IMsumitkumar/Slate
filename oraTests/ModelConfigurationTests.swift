import Foundation
@testable import Slate
import SwiftData
import Testing

/// Covers the first-launch store-directory bug: SwiftData does not create
/// intermediate directories, so on a fresh install the database URL pointed into
/// a folder that did not exist yet.
struct ModelConfigurationTests {
    private func makeTemporaryDirectory() throws -> URL {
        let url = URL.temporaryDirectory.appending(path: "SlateTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test func databaseURLCreatesItsContainingDirectory() throws {
        let support = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: support) }

        let expectedDirectory = support.appending(path: "Slate", directoryHint: .isDirectory)
        #expect(FileManager.default.fileExists(atPath: expectedDirectory.path) == false)

        let url = ModelConfiguration.databaseURL(in: support)

        var isDirectory: ObjCBool = false
        #expect(FileManager.default.fileExists(atPath: expectedDirectory.path, isDirectory: &isDirectory))
        #expect(isDirectory.boolValue)
        #expect(url == expectedDirectory.appending(path: "SlateData.sqlite"))
    }

    @Test func databaseURLCreatesMissingIntermediateDirectories() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        // Mirrors a fresh sandbox container, where "Application Support" itself is absent.
        let support = root.appending(path: "Library/Application Support", directoryHint: .isDirectory)
        #expect(FileManager.default.fileExists(atPath: support.path) == false)

        let url = ModelConfiguration.databaseURL(in: support)

        #expect(FileManager.default.fileExists(atPath: url.deletingLastPathComponent().path))
    }

    @Test func databaseURLIsIdempotent() throws {
        let support = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: support) }

        let first = ModelConfiguration.databaseURL(in: support)
        // A second call must not throw or change the answer when the directory exists.
        let second = ModelConfiguration.databaseURL(in: support)

        #expect(first == second)
        #expect(FileManager.default.fileExists(atPath: first.deletingLastPathComponent().path))
    }

    @Test func privateConfigurationStaysInMemoryAndTouchesNoDisk() {
        let configuration = ModelConfiguration.oraDatabase(isPrivate: true)

        // A private window must never write a store to disk.
        #expect(configuration.isStoredInMemoryOnly)
    }
}
