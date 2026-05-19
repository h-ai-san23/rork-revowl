import SwiftUI

struct HotelProfileView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var editingName: Bool = false
    @State private var editingAddress: Bool = false
    @State private var nameText: String = ""
    @State private var addressText: String = ""
    @State private var selectedStrategy: PricingStrategy = .balanced
    @State private var riskTolerance: Double = 0.5
    @State private var maxAdjustment: Double = 0.15

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                hotelHeader
                propertyDetailsSection
                roomTypesSection
                pricingSection
                dangerZone
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .navigationTitle("Hotel Profile")
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        .deepGlassBackground()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
                    .foregroundStyle(RevOwlTheme.gold)
            }
        }
        .onAppear {
            nameText = appState.hotel.name
            addressText = appState.hotel.address
            selectedStrategy = appState.hotel.pricingStrategy
            riskTolerance = appState.hotel.riskTolerance
            maxAdjustment = appState.hotel.maxRateAdjustment
        }
    }

    private var hotelHeader: some View {
        VStack(spacing: 16) {
            Image(systemName: "building.fill")
                .font(.system(size: 48))
                .foregroundStyle(RevOwlTheme.gold)
                .shadow(color: RevOwlTheme.gold.opacity(0.4), radius: 12)

            VStack(spacing: 6) {
                if editingName {
                    TextField("Hotel Name", text: $nameText)
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                        .padding(10)
                        .background(Color.primary.opacity(0.04), in: .rect(cornerRadius: 10))
                        .onSubmit {
                            appState.hotel.name = nameText
                            editingName = false
                        }
                } else {
                    Button {
                        editingName = true
                    } label: {
                        HStack(spacing: 6) {
                            Text(appState.hotel.name.isEmpty ? "Your Hotel" : appState.hotel.name)
                                .font(.title2.bold())
                                .foregroundStyle(.primary)
                            Image(systemName: "pencil")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }

                if editingAddress {
                    TextField("Address", text: $addressText)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .padding(8)
                        .background(Color.primary.opacity(0.04), in: .rect(cornerRadius: 8))
                        .onSubmit {
                            appState.hotel.address = addressText
                            editingAddress = false
                        }
                } else {
                    Button {
                        editingAddress = true
                    } label: {
                        HStack(spacing: 4) {
                            Text(appState.hotel.address.isEmpty ? "Add address" : appState.hotel.address)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Image(systemName: "pencil")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }

            HStack(spacing: 2) {
                ForEach(1...5, id: \.self) { star in
                    Image(systemName: star <= appState.hotel.starRating ? "star.fill" : "star")
                        .font(.caption)
                        .foregroundStyle(star <= appState.hotel.starRating ? RevOwlTheme.gold : Color.gray.opacity(0.4))
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .glassCardStyle()
    }

    private var propertyDetailsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Property Details")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 16)

            VStack(spacing: 0) {
                detailRow(icon: "building.2", label: "Property Type", value: appState.hotel.propertyType.rawValue)
                glassDivider
                detailRow(icon: "bed.double", label: "Total Rooms", value: "\(appState.hotel.totalRooms)")
                glassDivider
                detailRow(icon: "star.fill", label: "Star Rating", value: "\(appState.hotel.starRating) Stars")
                glassDivider
                detailRow(icon: "mappin.and.ellipse", label: "Location", value: String(format: "%.4f, %.4f", appState.hotel.latitude, appState.hotel.longitude))
                glassDivider
                detailRow(icon: "crown.fill", label: "Subscription", value: appState.currentTier.displayName)
            }
            .glassCardStyle()
        }
    }

    private var roomTypesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Room Types")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 16)

            VStack(spacing: 8) {
                ForEach(appState.hotel.roomTypes) { roomType in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(roomType.name)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                            Text("\(roomType.count) rooms")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(roomType.baseRate, format: .currency(code: "USD").precision(.fractionLength(0)))
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.primary)
                            Text("Floor: \(roomType.floorRate, format: .currency(code: "USD").precision(.fractionLength(0)))")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(14)
                    .glassCardStyle(cornerRadius: 14, elevation: .subtle)
                }
            }
        }
    }

    private var pricingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Pricing Configuration")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 16)

            VStack(spacing: 16) {
                strategyPicker
                riskToleranceSlider
                maxAdjustmentSlider
            }
            .padding(16)
            .glassCardStyle()
        }
    }

    private var strategyPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Strategy")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
            ForEach(PricingStrategy.allCases) { strategy in
                Button {
                    selectedStrategy = strategy
                    appState.hotel.pricingStrategy = strategy
                } label: {
                    strategyRow(strategy)
                }
                .sensoryFeedback(.selection, trigger: selectedStrategy)
            }
        }
    }

    private func strategyRow(_ strategy: PricingStrategy) -> some View {
        let isActive = selectedStrategy == strategy
        return HStack(spacing: 10) {
            Image(systemName: strategy.icon)
                .foregroundStyle(isActive ? RevOwlTheme.gold : .secondary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 1) {
                Text(strategy.rawValue)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                Text(strategy.description)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: isActive ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isActive ? RevOwlTheme.gold : Color.gray.opacity(0.4))
        }
        .padding(10)
        .background(isActive ? RevOwlTheme.gold.opacity(0.06) : Color.clear, in: .rect(cornerRadius: 10))
    }

    private var riskToleranceSlider: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Risk Tolerance")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                Spacer()
                Text(riskTolerance < 0.33 ? "Conservative" : riskTolerance < 0.66 ? "Moderate" : "Aggressive")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(RevOwlTheme.gold.opacity(0.15), in: .capsule)
                    .foregroundStyle(RevOwlTheme.gold)
            }
            Slider(value: $riskTolerance, in: 0...1)
                .tint(RevOwlTheme.gold)
                .onChange(of: riskTolerance) { _, newValue in
                    appState.hotel.riskTolerance = newValue
                }
        }
    }

    private var maxAdjustmentSlider: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Max Rate Adjustment")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                Spacer()
                Text("±\(Int(maxAdjustment * 100))%")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(RevOwlTheme.gold.opacity(0.15), in: .capsule)
                    .foregroundStyle(RevOwlTheme.gold)
            }
            Slider(value: $maxAdjustment, in: 0.05...0.30, step: 0.05)
                .tint(RevOwlTheme.gold)
                .onChange(of: maxAdjustment) { _, newValue in
                    appState.hotel.maxRateAdjustment = newValue
                }
        }
    }

    private var dangerZone: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Account")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 16)

            VStack(spacing: 0) {
                detailRow(icon: "person.fill", label: "Owner ID", value: String(appState.hotel.ownerId.prefix(8)) + "...")
                glassDivider
                detailRow(icon: "calendar", label: "Member Since", value: Date.now.formatted(.dateTime.month(.wide).year()))
            }
            .glassCardStyle()
        }
    }

    private var glassDivider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.05))
            .frame(height: 0.5)
            .padding(.leading, 44)
    }

    private func detailRow(icon: String, label: String, value: String) -> some View {
        HStack {
            Label(label, systemImage: icon)
                .font(.subheadline)
                .foregroundStyle(.primary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(14)
    }
}
