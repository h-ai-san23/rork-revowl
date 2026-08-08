import SwiftUI
import RevenueCat

@main
struct RevOwlAIHotelRevenueApp: App {
    @State private var appState = AppState()
    @State private var store: StoreViewModel

    init() {
        #if DEBUG
        Purchases.logLevel = .debug
        Purchases.configure(withAPIKey: Config.EXPO_PUBLIC_REVENUECAT_TEST_API_KEY)
        #else
        Purchases.configure(withAPIKey: Config.EXPO_PUBLIC_REVENUECAT_IOS_API_KEY)
        #endif
        _store = State(initialValue: StoreViewModel())
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .environment(store)
                .preferredColorScheme(.dark)
                .tint(RevOwlTheme.gold)
        }
    }
}
