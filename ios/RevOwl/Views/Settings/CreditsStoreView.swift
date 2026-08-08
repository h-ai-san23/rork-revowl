import SwiftUI
import RevenueCat

struct CreditsStoreView: View {
    @Environment(StoreViewModel.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var showPurchaseSuccess = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                header
                balanceCard
                packCard
                footnotes
            }
            .padding(20)
        }
        .navigationTitle("Credits")
        .navigationBarTitleDisplayMode(.inline)
        .deepGlassBackground()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
                    .foregroundStyle(RevOwlTheme.gold)
            }
        }
        .task {
            if store.offerings == nil {
                await store.fetchOfferings()
            }
        }
        .alert("Credits Added", isPresented: $showPurchaseSuccess) {
            Button("Great!", role: .cancel) { store.lastGrantedCredits = nil }
        } message: {
            Text("\(store.lastGrantedCredits ?? StoreViewModel.creditsPerPack) credits were added to your balance.")
        }
        .alert("Error", isPresented: errorBinding) {
            Button("OK") { store.errorMessage = nil }
        } message: {
            Text(store.errorMessage ?? "")
        }
        .onChange(of: store.lastGrantedCredits) { _, granted in
            if granted != nil { showPurchaseSuccess = true }
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } }
        )
    }

    private var header: some View {
        VStack(spacing: 10) {
            Image(systemName: "sparkles.rectangle.stack.fill")
                .font(.system(size: 44))
                .foregroundStyle(RevOwlTheme.gold)
                .shadow(color: RevOwlTheme.gold.opacity(0.4), radius: 12)
            Text("RevOwl Credits")
                .font(.title2.bold())
                .foregroundStyle(.primary)
            Text("Use credits for extra rate refreshes\nand on-demand event scans.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    private var balanceCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Your Balance")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(store.creditsBalance)")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(RevOwlTheme.gold)
                    .contentTransition(.numericText())
                    .animation(.snappy, value: store.creditsBalance)
            }
            Spacer()
            Image(systemName: "circle.hexagongrid.circle.fill")
                .font(.system(size: 40))
                .foregroundStyle(RevOwlTheme.gold.opacity(0.5))
        }
        .padding(18)
        .glassCardStyle(cornerRadius: 16)
    }

    @ViewBuilder
    private var packCard: some View {
        if store.isLoading {
            ProgressView("Loading products…")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
        } else if let package = store.creditsPackage {
            VStack(spacing: 14) {
                HStack(spacing: 14) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(RevOwlTheme.gold)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(StoreViewModel.creditsPerPack) Credits")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text("One-time purchase")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(package.storeProduct.localizedPriceString)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(RevOwlTheme.gold)
                }

                Button {
                    Task { await store.purchaseCredits() }
                } label: {
                    if store.isPurchasing {
                        ProgressView()
                            .tint(.black)
                    } else {
                        Text("Buy \(StoreViewModel.creditsPerPack) Credits")
                    }
                }
                .buttonStyle(GoldButtonStyle())
                .disabled(store.isPurchasing)
                .sensoryFeedback(.impact(weight: .medium), trigger: store.isPurchasing)
            }
            .padding(18)
            .glassCardStyle(cornerRadius: 16)
        } else {
            ContentUnavailableView {
                Label("Unavailable", systemImage: "exclamationmark.triangle")
            } description: {
                Text("The credits pack couldn't be loaded.")
            } actions: {
                Button("Retry") {
                    Task { await store.fetchOfferings() }
                }
                .foregroundStyle(RevOwlTheme.gold)
            }
        }
    }

    private var footnotes: some View {
        VStack(spacing: 12) {
            Button("Restore Purchases") {
                Task { await store.restore() }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .disabled(store.isRestoring)

            Text("Credits are added instantly after purchase and stay on this device.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
    }
}
