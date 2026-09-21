import Foundation

struct TemporaryImageStore: Sendable {
    private let directoryURL: URL

    nonisolated init(directoryURL: URL? = nil) {
        if let directoryURL {
            self.directoryURL = directoryURL
        } else {
            let base = FileManager.default.temporaryDirectory
            self.directoryURL = base.appendingPathComponent("zuvano-intake-images", isDirectory: true)
        }
    }

    nonisolated func save(imageData: Data, intakeID: UUID) throws -> String {
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let fileName = "\(intakeID.uuidString).img"
        let fileURL = directoryURL.appendingPathComponent(fileName)
        try imageData.write(to: fileURL, options: .atomic)
        return fileName
    }

    nonisolated func load(fileName: String) throws -> Data {
        let fileURL = directoryURL.appendingPathComponent(fileName)
        return try Data(contentsOf: fileURL)
    }

    nonisolated func delete(fileName: String?) {
        guard let fileName else { return }
        let fileURL = directoryURL.appendingPathComponent(fileName)
        try? FileManager.default.removeItem(at: fileURL)
    }

    nonisolated func deleteAll(for intakeID: UUID) {
        delete(fileName: "\(intakeID.uuidString).img")
    }
}
