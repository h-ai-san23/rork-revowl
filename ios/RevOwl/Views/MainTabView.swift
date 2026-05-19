import SwiftUI

struct MainTabView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedTab: Int = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Dashboard", systemImage: "chart.bar.fill", value: 0) {
                NavigationStack {
                    DashboardView()
                }
            }

            Tab("Competitors", systemImage: "building.2.fill", value: 1) {
                NavigationStack {
                    CompetitorListView()
                }
            }

            Tab("Dynamic Rates", systemImage: "sparkles", value: 2) {
                NavigationStack {
                    RecommendationsView()
                }
            }

            Tab("Alerts", systemImage: "bell.fill", value: 3) {
                NavigationStack {
                    AlertsView()
                }
                .badge(appState.unreadAlertCount)
            }

            Tab("Settings", systemImage: "gearshape.fill", value: 4) {
                NavigationStack {
                    SettingsView()
                }
            }
        }
        .tint(RevOwlTheme.gold)
        .sensoryFeedback(.selection, trigger: selectedTab)
    }
}
