import SwiftUI
import SwiftData

@main
struct MyFinanceApp: App {
    let container = ModelContainerService.shared.container

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .modelContainer(container)
                .onAppear {
                    ModelContainerService.shared.ensureUserProfile()
                }
        }
    }
}
