import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    @State private var showVoiceInput = false

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                DashboardView()
                    .tabItem { Label("Dashboard", systemImage: "house.fill") }
                    .tag(0)

                TransactionListView()
                    .tabItem { Label("Transaksi", systemImage: "list.bullet") }
                    .tag(1)

                InvestmentViewMain()
                    .tabItem { Label("Investasi", systemImage: "chart.line.uptrend.xyaxis") }
                    .tag(2)
                
                SettingsView()
                    .tabItem { Label("Pengaturan", systemImage: "gearshape.fill") }
                    .tag(3)
            }

            // Floating voice button
            VoiceInputButton(isPresented: $showVoiceInput)
                .padding(.bottom, 16)
        }
        .sheet(isPresented: $showVoiceInput) {
            VoiceReviewSheet()
        }
    }
}
