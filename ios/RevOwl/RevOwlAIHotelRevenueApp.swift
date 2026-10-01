import RevenueCat
import SwiftUI

@main
struct RevOwlAIHotelRevenueApp: App {
    @State private var app = AppModel()
    @State private var store = StoreViewModel()

    init() {
        if LaunchFlags.resetForUITests {
            Keychain.delete("session_token")
            Keychain.delete("device_secret")
            UserDefaults.standard.removeObject(forKey: "revowl.currentPropertyId")
        }
        #if DEBUG
        Purchases.logLevel = .warn
        Purchases.configure(withAPIKey: Config.EXPO_PUBLIC_REVENUECAT_TEST_API_KEY)
        #else
        Purchases.configure(withAPIKey: Config.EXPO_PUBLIC_REVENUECAT_IOS_API_KEY)
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(app)
                .environment(store)
                .tint(Palette.teal)
        }
    }
}
