import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("hasCompletedSetup") private var hasCompletedSetup = false

    var body: some View {
        Group {
            if !appState.hasCompletedOnboarding || !hasCompletedOnboarding {
                OnboardingView(onComplete: {
                    withAnimation(.smooth(duration: 0.5)) {
                        hasCompletedOnboarding = true
                        appState.hasCompletedOnboarding = true
                    }
                })
            } else if !appState.hasCompletedSetup || !hasCompletedSetup {
                SetupWizardView(onComplete: {
                    withAnimation(.smooth(duration: 0.5)) {
                        hasCompletedSetup = true
                        appState.hasCompletedSetup = true
                    }
                })
            } else {
                MainTabView()
            }
        }
        .onChange(of: appState.hasCompletedOnboarding) { _, newValue in
            if !newValue {
                withAnimation(.smooth(duration: 0.5)) {
                    hasCompletedOnboarding = false
                    hasCompletedSetup = false
                }
            }
        }
    }
}
