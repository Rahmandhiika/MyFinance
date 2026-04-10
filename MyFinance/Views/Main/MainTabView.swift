import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: Int = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)

            TrackerView()
                .tabItem {
                    Label("Tracker", systemImage: "list.bullet.rectangle")
                }
                .tag(1)

            VoiceTabView()
                .tabItem {
                    Label("Voice", systemImage: "mic.fill")
                }
                .tag(2)

            InvestTabView()
                .tabItem {
                    Label("Invest", systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(3)

            PocketTabView()
                .tabItem {
                    Label("Pocket", systemImage: "wallet.pass.fill")
                }
                .tag(4)
        }
    }
}
