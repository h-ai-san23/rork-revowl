import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var app
    @Environment(StoreViewModel.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        @Bindable var app = app
        ZStack {
            AppBackground()
            switch app.route {
            case .launching:
                LaunchView()
                    .transition(.opacity)
            case .onboarding:
                OnboardingFlow()
                    .transition(.opacity)
            case .main:
                MainTabView()
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.98)))
            }
        }
        .animation(.smooth(duration: 0.4), value: app.route)
        .task { await app.bootstrap() }
        .onChange(of: app.propertyId, initial: true) { _, id in
            Task {
                if let id {
                    await store.activate(propertyId: id)
                } else {
                    await store.deactivate()
                }
            }
        }
        .sheet(isPresented: $app.showPaywall) {
            PaywallSheet()
        }
    }
}

private struct LaunchView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        VStack(spacing: 20) {
            OrevView(state: app.launchError == nil ? .thinking : .errorRecovery, size: 140)
            if let error = app.launchError {
                Text(error)
                    .font(.body)
                    .foregroundStyle(Palette.inkSecondary)
                    .multilineTextAlignment(.center)
                Button("Try again") {
                    Task { await app.bootstrap() }
                }
                .buttonStyle(PrimaryButtonStyle())
                .frame(maxWidth: 260)
            } else {
                Text("revOWL")
                    .font(.display(.largeTitle, weight: .bold))
                    .foregroundStyle(Palette.ink)
                Text("Opening your property…")
                    .font(.subheadline)
                    .foregroundStyle(Palette.inkTertiary)
            }
        }
        .padding(Metrics.margin)
    }
}
