import SwiftUI

struct MainTabView: View {
    @Environment(\.appTheme) private var theme
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem { Label("Home", systemImage: "square.grid.2x2.fill") }
                .tag(0)

            TransaksiTabView()
                .tabItem { Label("Transaksi", systemImage: "list.bullet") }
                .tag(1)

            NavigationStack { AIAdvisorView() }
                .tabItem { Label("AI", systemImage: "brain.head.profile") }
                .tag(2)

            PocketTabView()
                .tabItem { Label("Pocket", systemImage: "wallet.pass.fill") }
                .tag(3)

            NavigationStack { AnalitikView() }
                .tabItem { Label("Analitik", systemImage: "chart.bar.fill") }
                .tag(4)
        }
        .tint(theme.tabBarTint)
    }
}
