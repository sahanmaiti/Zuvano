import Foundation
import Testing
@testable import Zuvano

@Suite struct ShareHandoffTests {
    @Test func roundTripTextHandoff() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("zuvano-handoff-tests-\(UUID().uuidString)", isDirectory: true)
        let store = ShareHandoffStore(handoffDirectoryURL: directory)

        let writeResult = try store.write(source: .sharedText("Meet Friday at 7"))
        let loaded = try store.load(token: writeResult.token)

        #expect(loaded.type == .shareText)
        #expect(loaded.text == "Meet Friday at 7")
        #expect(loaded.imageData == nil)

        store.delete(token: writeResult.token)
        #expect(store.pendingTokens().isEmpty)
    }

    @Test func roundTripImageHandoff() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("zuvano-handoff-tests-\(UUID().uuidString)", isDirectory: true)
        let store = ShareHandoffStore(handoffDirectoryURL: directory)
        let imageBytes = Data([0x89, 0x50, 0x4E, 0x47])

        let writeResult = try store.write(source: .sharedImage(imageBytes))
        let loaded = try store.load(token: writeResult.token)

        #expect(loaded.type == .shareImage)
        #expect(loaded.imageData == imageBytes)

        store.delete(token: writeResult.token)
        #expect(store.pendingTokens().isEmpty)
    }

    @Test func parsesHandoffURL() {
        let token = UUID()
        let url = URL(string: "zuvano://handoff/\(token.uuidString)")!
        #expect(ShareHandoffStore.parseHandoffToken(from: url) == token)
    }
}
