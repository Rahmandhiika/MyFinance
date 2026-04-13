import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem { Label("Ringkasan", systemImage: "square.grid.2x2.fill") }
                .tag(0)

            TransaksiTabView()
                .tabItem { Label("Transaksi", systemImage: "list.bullet") }
                .tag(1)

            VoiceTabView()
                .tabItem { Label("", systemImage: "mic.fill") }
                .tag(2)

            PocketTabView()
                .tabItem { Label("Pocket", systemImage: "wallet.pass.fill") }
                .tag(3)

            PengaturanView()
                .tabItem { Label("Pengaturan", systemImage: "gearshape.fill") }
                .tag(4)
        }
        .tint(Color(hex: "#22C55E"))
    }
}
