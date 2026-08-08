import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(StoreViewModel.self) private var store
    @State private var showSubscription = false
    @State private var showCreditsStore = false
    @State private var showDemandSignals = false
    @State private var showNotificationSettings = false
    @State private var showHotelProfile = false
    @State private var showCompetitorManagement = false
    @State private var showSignOutConfirmation = false
    @State private var isRestoringPurchases = false
    @State private var showRestoreResult = false
    @State private var restoreResultMessage = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Button {
                    showHotelProfile = true
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "building.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(RevOwlTheme.gold)
                            .frame(width: 52, height: 52)
                            .background {
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(RevOwlTheme.gold.opacity(0.12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .strokeBorder(RevOwlTheme.gold.opacity(0.2), lineWidth: 0.5)
                                    )
                            }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(appState.hotel.name.isEmpty ? "Your Hotel" : appState.hotel.name)
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text("\(appState.hotel.totalRooms) rooms • \(appState.hotel.propertyType.rawValue)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(16)
                    .glassCardStyle()
                }
                .buttonStyle(GlassPressButtonStyle())
                .sensoryFeedback(.selection, trigger: showHotelProfile)

                settingsSection(title: "Subscription") {
                    VStack(spacing: 0) {
                        Button {
                            showSubscription = true
                        } label: {
                            HStack {
                                Label("Current Plan", systemImage: "crown.fill")
                                    .foregroundStyle(.primary)
                                Spacer()
                                Text(appState.currentTier.displayName)
                                    .foregroundStyle(RevOwlTheme.gold)
                                    .fontWeight(.semibold)
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(14)
                        }
                        .sensoryFeedback(.selection, trigger: showSubscription)

                        glassDivider
                        settingsInfoRow(icon: "arrow.clockwise", title: "Rate Refresh", value: appState.currentTier.refreshInterval)
                        glassDivider
                        Button {
                            showCompetitorManagement = true
                        } label: {
                            HStack {
                                Label("Competitors", systemImage: "building.2")
                                    .foregroundStyle(.primary)
                                Spacer()
                                Text("\(appState.competitors.count)/\(appState.currentTier.competitorLimit)")
                                    .foregroundStyle(.secondary)
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(14)
                        }
                        .sensoryFeedback(.selection, trigger: showCompetitorManagement)
                        glassDivider
                        settingsInfoRow(icon: "clock", title: "History", value: "\(appState.currentTier.historyDays) days")
                    }
                    .glassCardStyle()
                }

                settingsSection(title: "Intelligence") {
                    VStack(spacing: 0) {
                        Button {
                            showDemandSignals = true
                        } label: {
                            HStack {
                                Label("Demand Signals", systemImage: "waveform.path.ecg")
                                    .foregroundStyle(.primary)
                                Spacer()
                                DemandGaugeView(score: appState.demandScore, size: 32)
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(14)
                        }
                        .sensoryFeedback(.selection, trigger: showDemandSignals)

                        glassDivider
                        settingsInfoRow(icon: appState.hotel.pricingStrategy.icon, title: "Pricing Strategy", value: appState.hotel.pricingStrategy.rawValue)
                        glassDivider
                        settingsInfoRow(icon: "slider.horizontal.3", title: "Risk Tolerance", value: appState.hotel.riskTolerance < 0.33 ? "Conservative" : appState.hotel.riskTolerance < 0.66 ? "Moderate" : "Aggressive")
                    }
                    .glassCardStyle()
                }

                settingsSection(title: "Notifications") {
                    VStack(spacing: 0) {
                        Button {
                            showNotificationSettings = true
                        } label: {
                            HStack {
                                Label("Notification Settings", systemImage: "bell.badge.fill")
                                    .foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(14)
                        }
                        .sensoryFeedback(.selection, trigger: showNotificationSettings)
                    }
                    .glassCardStyle()
                }

                settingsSection(title: "Purchases") {
                    VStack(spacing: 0) {
                        Button {
                            showCreditsStore = true
                        } label: {
                            HStack {
                                Label("Credits", systemImage: "sparkles.rectangle.stack.fill")
                                    .foregroundStyle(.primary)
                                Spacer()
                                Text("\(store.creditsBalance)")
                                    .foregroundStyle(RevOwlTheme.gold)
                                    .fontWeight(.semibold)
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(14)
                        }
                        .sensoryFeedback(.selection, trigger: showCreditsStore)

                        glassDivider

                        Button {
                            isRestoringPurchases = true
                            Task {
                                await store.restore()
                                isRestoringPurchases = false
                                restoreResultMessage = store.errorMessage ?? "Purchases restored. Current plan: \(appState.currentTier.displayName)"
                                store.errorMessage = nil
                                showRestoreResult = true
                            }
                        } label: {
                            HStack {
                                Label("Restore Purchases", systemImage: "arrow.clockwise.circle.fill")
                                    .foregroundStyle(.primary)
                                Spacer()
                                if isRestoringPurchases {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .padding(14)
                        }
                        .disabled(isRestoringPurchases)
                        .sensoryFeedback(.impact(weight: .medium), trigger: isRestoringPurchases)
                    }
                    .glassCardStyle()
                }

                settingsSection(title: "About") {
                    VStack(spacing: 0) {
                        settingsInfoRow(icon: "info.circle", title: "Version", value: "1.0.0")
                        glassDivider

                        Link(destination: URL(string: "https://revowl.ai")!) {
                            HStack {
                                Label("Website", systemImage: "globe")
                                    .foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(14)
                        }

                        glassDivider

                        Link(destination: URL(string: "https://revowl.ai/support")!) {
                            HStack {
                                Label("Help & Support", systemImage: "questionmark.circle")
                                    .foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(14)
                        }

                        glassDivider

                        Link(destination: URL(string: "https://revowl.ai/privacy")!) {
                            HStack {
                                Label("Privacy Policy", systemImage: "lock.shield")
                                    .foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(14)
                        }
                    }
                    .glassCardStyle()
                }

                settingsSection(title: "") {
                    Button {
                        showSignOutConfirmation = true
                    } label: {
                        HStack {
                            Spacer()
                            Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(RevOwlTheme.negative)
                            Spacer()
                        }
                        .padding(14)
                        .glassCardStyle()
                    }
                    .sensoryFeedback(.warning, trigger: showSignOutConfirmation)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .navigationTitle("Settings")
        .deepGlassBackground()
        .alert("Sign Out", isPresented: $showSignOutConfirmation) {
            Button("Sign Out", role: .destructive) {
                appState.signOut()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to sign out? Your data will be cleared from this device.")
        }
        .alert("Restore Complete", isPresented: $showRestoreResult) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(restoreResultMessage)
        }
        .sheet(isPresented: $showSubscription) {
            NavigationStack {
                SubscriptionView()
            }
        }
        .sheet(isPresented: $showCreditsStore) {
            NavigationStack {
                CreditsStoreView()
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationContentInteraction(.scrolls)
        }
        .sheet(isPresented: $showDemandSignals) {
            NavigationStack {
                DemandDetailView()
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationContentInteraction(.scrolls)
        }
        .sheet(isPresented: $showNotificationSettings) {
            NavigationStack {
                NotificationSettingsView()
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationContentInteraction(.scrolls)
        }
        .sheet(isPresented: $showHotelProfile) {
            NavigationStack {
                HotelProfileView()
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationContentInteraction(.scrolls)
        }
        .sheet(isPresented: $showCompetitorManagement) {
            NavigationStack {
                CompetitorManagementView()
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationContentInteraction(.scrolls)
        }
    }

    private var glassDivider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.05))
            .frame(height: 0.5)
            .padding(.leading, 44)
    }

    private func settingsSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 16)
            content()
        }
    }

    private func settingsInfoRow(icon: String, title: String, value: String) -> some View {
        HStack {
            Label(title, systemImage: icon)
                .foregroundStyle(.primary)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
        .padding(14)
    }
}
