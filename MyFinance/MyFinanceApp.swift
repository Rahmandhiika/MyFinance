import SwiftUI
import SwiftData

@main   
struct MyFinanceApp: App {
    let containerService = ModelContainerService.shared

    init() {
        containerService.ensureUserProfile()
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .modelContainer(containerService.container)
                .preferredColorScheme(.dark)
        }
    }
}
