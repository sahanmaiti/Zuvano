import SwiftUI

@main
struct ZuvanoApp: App {
    @State private var homeViewModel = HomeViewModel()

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                HomeView(viewModel: homeViewModel)
            }
        }
    }
}
