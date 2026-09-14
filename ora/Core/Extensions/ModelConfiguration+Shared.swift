import Foundation
import SwiftData

extension ModelConfiguration {
    /// Shared model configuration for the main Slate database
    static func oraDatabase(isPrivate: Bool = false) -> ModelConfiguration {
        if isPrivate {
            return ModelConfiguration(isStoredInMemoryOnly: true)
        } else {
            return ModelConfiguration(
                "OraData",
                schema: Schema([TabContainer.self, History.self, Download.self]),
                url: databaseURL()
            )
        }
    }

    /// Resolves the on-disk store URL, creating its containing directory first.
    ///
    /// SwiftData does not create intermediate directories for a store URL. On a
    /// fresh install the app's Application Support folder is empty, so opening the
    /// store failed until some other component happened to create the directory
    /// first — which made first-launch persistence depend on start-up ordering.
    static func databaseURL(in supportDirectory: URL = URL.applicationSupportDirectory) -> URL {
        let directory = supportDirectory.appending(path: "Slate", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appending(path: "SlateData.sqlite")
    }

    /// Creates a ModelContainer using the standard Slate database configuration
    static func createOraContainer(isPrivate: Bool = false) throws -> ModelContainer {
        return try ModelContainer(
            for: TabContainer.self, History.self, Download.self,
            configurations: oraDatabase(isPrivate: isPrivate)
        )
    }
}
