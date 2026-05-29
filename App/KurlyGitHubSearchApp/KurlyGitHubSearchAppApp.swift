import SwiftUI

@main
struct KurlyGitHubSearchAppApp: App {

    private let container = AppDIContainer()

    var body: some Scene {
        WindowGroup {
            AppRootView(container: container)
        }
    }
}
