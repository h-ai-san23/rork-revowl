import SwiftUI

struct MainTabView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        @Bindable var app = app
        TabView(selection: $app.selectedTab) {
            Tab("Today", systemImage: "sun.horizon", value: AppTab.today) {
                NavigationStack { TodayView() }
            }
            Tab("Market", systemImage: "chart.xyaxis.line", value: AppTab.market) {
                NavigationStack { MarketView() }
            }
            Tab("Calendar", systemImage: "calendar", value: AppTab.calendar) {
                NavigationStack { CalendarView() }
            }
            Tab("Ask Orev", systemImage: "bubble.left.and.text.bubble.right", value: AppTab.ask) {
                NavigationStack { AskView() }
            }
            Tab("Property", systemImage: "building.2", value: AppTab.property) {
                NavigationStack { PropertyView() }
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .sensoryFeedback(.selection, trigger: app.selectedTab)
    }
}
