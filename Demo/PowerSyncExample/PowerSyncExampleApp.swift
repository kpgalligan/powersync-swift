import SwiftUI

@main
struct PowerSyncExampleApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(SystemManager())
        }
    }
}
