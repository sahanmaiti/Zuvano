import SwiftData
import SwiftUI

@main
struct ZuvanoApp: App {
    private let modelContainer: ModelContainer

    init() {
        do {
            modelContainer = try ZuvanoModelContainer.make()
        } catch {
            fatalError("Failed to create model container.")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(modelContainer)
    }
}
