import SwiftUI

struct RateManagementView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var isLoadingOTA = false
    @State private var editingRoomTypeId: String?
    @State private var editRate: String = ""
    @State private var editSource: RateSource = .manual
    @FocusState private var rateFieldFocused: Bool
    @State private var keyboardDismissId = UUID()

    private let today = Date.now
    private var dateLabel: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: today)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                rateSummaryHeader

                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.caption)
                        .foregroundStyle(RevOwlTheme.gold)
                    Text("Rates for \(dateLabel) — 1 Night Stay")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("via Xotelo API")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassCardStyle(cornerRadius: 10, elevation: .subtle)

                displayModeToggle

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Your Rates by Room Type")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Spacer()
                        Button {
                            pullFromOTAs()
                        } label: {
                            HStack(spacing: 4) {
                                if isLoadingOTA {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                }
                                Text("Pull OTA Rates")
                            }
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(RevOwlTheme.gold.opacity(0.2), in: .capsule)
                            .overlay(Capsule().strokeBorder(RevOwlTheme.gold.opacity(0.3), lineWidth: 0.5))
                            .foregroundStyle(RevOwlTheme.gold)
                        }
                        .disabled(isLoadingOTA)
                        .sensoryFeedback(.impact(weight: .medium), trigger: isLoadingOTA)
                    }

                    if appState.rateDisplayMode == .perRoomType {
                        ForEach(appState.hotelRates) { entry in
                            rateCard(entry)
                        }
                    } else {
                        averageRateCard
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Rate Sources")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("Rates are fetched in real-time from OTA listings via Xotelo API. Each OTA rate shown is the actual listed price for that room type on that platform.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineSpacing(2)

                    VStack(spacing: 0) {
                        sourceInfoRow(icon: "b.circle.fill", name: "Booking.com", color: .blue)
                        divider
                        sourceInfoRow(icon: "t.circle.fill", name: "Trip.com", color: .cyan)
                        divider
                        sourceInfoRow(icon: "a.circle.fill", name: "Agoda.com", color: .pink)
                        divider
                        sourceInfoRow(icon: "e.circle.fill", name: "Expedia", color: .yellow)
                        divider
                        sourceInfoRow(icon: "h.circle.fill", name: "Hotels.com", color: .red)
                        divider
                        sourceInfoRow(icon: "p.circle.fill", name: "Priceline", color: .blue)
                        divider
                        sourceInfoRow(icon: "g.circle.fill", name: "Google Hotels", color: .green)
                    }
                    .padding(.top, 4)
                }
                .padding(16)
                .glassCardStyle(cornerRadius: 16, elevation: .subtle)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("My Rates")
        .navigationBarTitleDisplayMode(.inline)
        .deepGlassBackground()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
                    .foregroundStyle(RevOwlTheme.gold)
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    rateFieldFocused = false
                }
                .foregroundStyle(RevOwlTheme.gold)
            }
        }
    }

    private var displayModeToggle: some View {
        HStack(spacing: 0) {
            Button {
                withAnimation(.snappy) { appState.rateDisplayMode = .perRoomType }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "bed.double.fill")
                        .font(.caption2)
                    Text("By Room Type")
                        .font(.caption.weight(.medium))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    appState.rateDisplayMode == .perRoomType
                        ? RevOwlTheme.gold.opacity(0.25)
                        : Color.clear,
                    in: .capsule
                )
                .overlay(
                    appState.rateDisplayMode == .perRoomType
                        ? Capsule().strokeBorder(RevOwlTheme.gold.opacity(0.4), lineWidth: 0.5)
                        : nil
                )
                .foregroundStyle(appState.rateDisplayMode == .perRoomType ? RevOwlTheme.gold : .secondary)
            }
            .sensoryFeedback(.selection, trigger: appState.rateDisplayMode == .perRoomType)

            Button {
                withAnimation(.snappy) { appState.rateDisplayMode = .average }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chart.bar.fill")
                        .font(.caption2)
                    Text("Average Rate")
                        .font(.caption.weight(.medium))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    appState.rateDisplayMode == .average
                        ? RevOwlTheme.gold.opacity(0.25)
                        : Color.clear,
                    in: .capsule
                )
                .overlay(
                    appState.rateDisplayMode == .average
                        ? Capsule().strokeBorder(RevOwlTheme.gold.opacity(0.4), lineWidth: 0.5)
                        : nil
                )
                .foregroundStyle(appState.rateDisplayMode == .average ? RevOwlTheme.gold : .secondary)
            }
            .sensoryFeedback(.selection, trigger: appState.rateDisplayMode == .average)
        }
        .padding(4)
        .glassCardStyle(cornerRadius: 20, elevation: .subtle)
    }

    private var averageRateCard: some View {
        VStack(spacing: 14) {
            HStack {
                Text("All Room Types — Average")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
                Text(appState.avgRate, format: .currency(code: "USD").precision(.fractionLength(0)))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
            }

            let allOTAs = aggregatedOTARates()
            if !allOTAs.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(allOTAs.enumerated()), id: \.element.otaName) { index, ota in
                        HStack {
                            Text(ota.otaName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(ota.avgRate, format: .currency(code: "USD").precision(.fractionLength(0)))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Text("+\(ota.avgTax, format: .currency(code: "USD").precision(.fractionLength(0))) tax")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        if index < allOTAs.count - 1 {
                            Rectangle()
                                .fill(Color.primary.opacity(0.05))
                                .frame(height: 0.5)
                                .padding(.leading, 12)
                        }
                    }
                }
                .background(Color.primary.opacity(0.03), in: .rect(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
                )
            }

            HStack {
                Text("\(dateLabel) • 1 night • \(appState.hotelRates.count) room types averaged")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer()
            }
        }
        .padding(14)
        .glassCardStyle(cornerRadius: 16, elevation: .subtle)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.04))
            .frame(height: 0.5)
            .padding(.leading, 36)
    }

    private func sourceInfoRow(icon: String, name: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
                .frame(width: 20)
            Text(name)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text("via Xotelo API")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }

    private var rateSummaryHeader: some View {
        HStack(spacing: 16) {
            VStack(spacing: 4) {
                Text("Your Rate")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(appState.avgRate, format: .currency(code: "USD").precision(.fractionLength(0)))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                if let lowestSource = appState.hotelRates.min(by: { $0.currentRate < $1.currentRate }) {
                    Text(lowestSource.source.rawValue)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(16)
            .glassCardStyle()

            VStack(spacing: 4) {
                Text("Comp. Avg")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(appState.competitorAvgRate, format: .currency(code: "USD").precision(.fractionLength(0)))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                let diff = appState.avgRate - appState.competitorAvgRate
                Text(String(format: "%+.0f", diff))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(diff >= 0 ? RevOwlTheme.positive : RevOwlTheme.negative)
            }
            .frame(maxWidth: .infinity)
            .padding(16)
            .glassCardStyle()
        }
    }

    private func rateCard(_ entry: HotelRateEntry) -> some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: roomTypeIcon(entry.roomTypeName))
                            .font(.caption)
                            .foregroundStyle(RevOwlTheme.gold)
                        Text(entry.roomTypeName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                    }
                    HStack(spacing: 4) {
                        Image(systemName: entry.source.icon)
                            .font(.caption2)
                        Text(entry.source.rawValue)
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(entry.currentRate, format: .currency(code: "USD").precision(.fractionLength(0)))
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    Text("\(dateLabel) • 1 night")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            if !entry.otaRates.isEmpty {
                VStack(spacing: 0) {
                    ForEach(entry.otaRates) { ota in
                        HStack {
                            Text(ota.otaName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            VStack(alignment: .trailing, spacing: 1) {
                                Text(ota.rate, format: .currency(code: "USD").precision(.fractionLength(0)))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.primary)
                                if ota.tax > 0 {
                                    Text("+\(ota.tax, format: .currency(code: "USD").precision(.fractionLength(0))) tax")
                                        .font(.system(size: 9))
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        if ota.id != entry.otaRates.last?.id {
                            Rectangle()
                                .fill(Color.primary.opacity(0.05))
                                .frame(height: 0.5)
                                .padding(.leading, 12)
                        }
                    }
                }
                .background(Color.primary.opacity(0.03), in: .rect(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
                )

                HStack {
                    HStack(spacing: 4) {
                        Text("Low:")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Text(entry.lowestOTARate, format: .currency(code: "USD").precision(.fractionLength(0)))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(RevOwlTheme.positive)
                    }
                    Spacer()
                    HStack(spacing: 4) {
                        Text("Avg:")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Text(entry.averageOTARate, format: .currency(code: "USD").precision(.fractionLength(0)))
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(RevOwlTheme.gold)
                    }
                    Spacer()
                    HStack(spacing: 4) {
                        Text("High:")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Text(entry.highestOTARate, format: .currency(code: "USD").precision(.fractionLength(0)))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(RevOwlTheme.negative)
                    }
                }
            }

            HStack(spacing: 8) {
                if editingRoomTypeId == entry.roomTypeId {
                    TextField("Rate", text: $editRate)
                        .focused($rateFieldFocused)
                        .keyboardType(.decimalPad)
                        .padding(8)
                        .background(Color.primary.opacity(0.04), in: .rect(cornerRadius: 8))
                        .frame(width: 100)

                    Picker("Source", selection: $editSource) {
                        ForEach(RateSource.allCases) { source in
                            Text(source.rawValue).tag(source)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(RevOwlTheme.gold)

                    Button("Save") {
                        if let newRate = Double(editRate) {
                            appState.updateHotelRate(roomTypeId: entry.roomTypeId, rate: newRate, source: editSource)
                        }
                        editingRoomTypeId = nil
                        rateFieldFocused = false
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(RevOwlTheme.gold)
                    .sensoryFeedback(.success, trigger: editingRoomTypeId == nil)

                    Button("Cancel") {
                        editingRoomTypeId = nil
                        rateFieldFocused = false
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                } else {
                    Button {
                        editingRoomTypeId = entry.roomTypeId
                        editRate = String(format: "%.0f", entry.currentRate)
                        editSource = entry.source
                        rateFieldFocused = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "pencil")
                            Text("Edit Rate")
                        }
                        .font(.caption.weight(.medium))
                        .foregroundStyle(RevOwlTheme.gold)
                    }
                    .sensoryFeedback(.selection, trigger: editingRoomTypeId)

                    Spacer()

                    if let roomType = appState.hotel.roomTypes.first(where: { $0.id == entry.roomTypeId }) {
                        Text("Floor: \(roomType.floorRate, format: .currency(code: "USD").precision(.fractionLength(0)))")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .padding(14)
        .glassCardStyle(cornerRadius: 16, elevation: .subtle)
    }

    private func roomTypeIcon(_ name: String) -> String {
        switch name {
        case "King": return "bed.double.fill"
        case "Double Queen": return "bed.double.fill"
        case "Suite": return "house.lodge.fill"
        case "Standard": return "bed.double"
        default: return "bed.double"
        }
    }

    private struct AggregatedOTA {
        let otaName: String
        let avgRate: Double
        let avgTax: Double
    }

    private func aggregatedOTARates() -> [AggregatedOTA] {
        var otaMap: [String: (rates: [Double], taxes: [Double])] = [:]
        for entry in appState.hotelRates {
            for ota in entry.otaRates {
                var existing = otaMap[ota.otaName] ?? (rates: [], taxes: [])
                existing.rates.append(ota.rate)
                existing.taxes.append(ota.tax)
                otaMap[ota.otaName] = existing
            }
        }
        return otaMap.map { name, data in
            AggregatedOTA(
                otaName: name,
                avgRate: data.rates.reduce(0, +) / Double(data.rates.count),
                avgTax: data.taxes.reduce(0, +) / Double(data.taxes.count)
            )
        }.sorted { $0.avgRate < $1.avgRate }
    }

    private func pullFromOTAs() {
        isLoadingOTA = true
        Task {
            let rateService = RateService()
            let otaRates = await rateService.fetchHotelOTARates(hotel: appState.hotel)
            for entry in otaRates {
                if let index = appState.hotelRates.firstIndex(where: { $0.roomTypeId == entry.roomTypeId }) {
                    appState.hotelRates[index].otaRates = entry.otaRates
                    appState.hotelRates[index].currentRate = entry.currentRate
                    appState.hotelRates[index].source = entry.source
                    appState.hotelRates[index].lastUpdated = .now
                }
            }
            isLoadingOTA = false
        }
    }
}
