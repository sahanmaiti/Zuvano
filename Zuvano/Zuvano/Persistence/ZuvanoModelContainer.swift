import Foundation
import SwiftData

enum ZuvanoModelContainer: Sendable {
    nonisolated static func make() throws -> ModelContainer {
        let schema = Schema([IntakeRecord.self, ActionDraftRecord.self])

        guard let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            return try ModelContainer(for: schema)
        }

        let storeDirectory = appSupport.appendingPathComponent("ZuvanoStore", isDirectory: true)
        try FileManager.default.createDirectory(
            at: storeDirectory,
            withIntermediateDirectories: true
        )
        excludeFromBackup(storeDirectory)

        let storeURL = storeDirectory.appendingPathComponent("default.store")
        let configuration = ModelConfiguration(url: storeURL)
        return try ModelContainer(for: schema, configurations: configuration)
    }

    nonisolated private static func excludeFromBackup(_ directoryURL: URL) {
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var mutableURL = directoryURL
        try? mutableURL.setResourceValues(values)
    }
}
