import SwiftUI

@main
struct RevOwlAIHotelRevenueApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .preferredColorScheme(.dark)
                .tint(RevOwlTheme.gold)
        }
    }
}
