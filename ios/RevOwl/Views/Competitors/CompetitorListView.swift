import SwiftUI

struct CompetitorListView: View {
    @Environment(AppState.self) private var appState
    @State private var showMap = false
    @State private var showManage = false
    @State private var selectedCompetitor: Competitor?
    @State private var animateAppear = false

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                summaryHeader
                    .staggeredAppear(index: 0, appear: animateAppear)

                if appState.isResolvingKeys {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                            .tint(RevOwlTheme.gold)
                        Text("Finding rate sources for competitors...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity)
                    .glassCardStyle(cornerRadius: 12, elevation: .subtle)
                }

                ForEach(Array(appState.competitors.enumerated()), id: \.element.id) { index, competitor in
                    Button {
                        selectedCompetitor = competitor
                    } label: {
                        CompetitorCard(competitor: competitor, displayMode: appState.rateDisplayMode)
                    }
                    .buttonStyle(GlassPressButtonStyle())
                    .sensoryFeedback(.impact(weight: .light), trigger: selectedCompetitor?.id)
                    .staggeredAppear(index: index + 1, appear: animateAppear)
                }

                Button {
                    showManage = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                        Text(appState.competitors.isEmpty ? "Add Competitors" : "Add or Manage Competitors")
                            .font(.subheadline.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(RevOwlTheme.gold.opacity(0.15), in: .rect(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(RevOwlTheme.gold.opacity(0.3), lineWidth: 0.5)
                    )
                    .foregroundStyle(RevOwlTheme.gold)
                }
                .sensoryFeedback(.selection, trigger: showManage)
                .staggeredAppear(index: appState.competitors.count + 1, appear: animateAppear)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .refreshable {
            await appState.refreshRates()
        }
        .navigationTitle("Competitors")
        .deepGlassBackground()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Map", systemImage: "map.fill") {
                    showMap = true
                }
                .foregroundStyle(RevOwlTheme.gold)
                .sensoryFeedback(.selection, trigger: showMap)
            }
            ToolbarItem(placement: .topBarLeading) {
                Button("Add", systemImage: "plus.circle.fill") {
                    showManage = true
                }
                .foregroundStyle(RevOwlTheme.gold)
                .sensoryFeedback(.selection, trigger: showManage)
            }
        }
        .sheet(isPresented: $showMap) {
            NavigationStack {
                CompetitorMapView()
            }
            .presentationDetents([.large])
        }
        .sheet(isPresented: $showManage) {
            NavigationStack {
                CompetitorManagementView()
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationContentInteraction(.scrolls)
        }
        .sheet(item: $selectedCompetitor) { competitor in
            NavigationStack {
                CompetitorDetailSheet(competitor: competitor)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationContentInteraction(.scrolls)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                animateAppear = true
            }
        }
    }

    private var summaryHeader: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Tracking \(appState.competitors.count) Hotels")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                HStack(spacing: 4) {
                    Circle()
                        .fill(appState.isRefreshingRates ? .orange : RevOwlTheme.positive)
                        .frame(width: 6, height: 6)
                    Text(appState.isRefreshingRates ? "Refreshing..." : "Updated \(appState.lastRateRefresh, style: .relative) ago")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button {
                Task { await appState.refreshRates() }
            } label: {
                HStack(spacing: 4) {
                    if appState.isRefreshingRates {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                    Text("Refresh")
                }
                .font(.caption.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(RevOwlTheme.gold.opacity(0.2), in: .capsule)
                .overlay(Capsule().strokeBorder(RevOwlTheme.gold.opacity(0.3), lineWidth: 0.5))
                .foregroundStyle(RevOwlTheme.gold)
            }
            .disabled(appState.isRefreshingRates)
            .sensoryFeedback(.impact(weight: .medium), trigger: appState.isRefreshingRates)
        }
        .padding(.top, 8)
    }
}

struct CompetitorCard: View {
    let competitor: Competitor
    let displayMode: RateDisplayMode

    private let today = Date.now
    private var dateLabel: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: today)
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(competitor.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        HStack(spacing: 1) {
                            ForEach(0..<competitor.stars, id: \.self) { _ in
                                Image(systemName: "star.fill")
                                    .font(.system(size: 9))
                                    .foregroundStyle(RevOwlTheme.gold)
                            }
                        }
                        Text("•")
                            .foregroundStyle(.tertiary)
                        Text(String(format: "%.1f mi", competitor.distance))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    if competitor.currentRate > 0 {
                        if displayMode == .average {
                            Text(competitor.averageOTARate, format: .currency(code: "USD").precision(.fractionLength(0)))
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundStyle(.primary)
                            Text("avg across OTAs")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        } else {
                            Text(competitor.currentRate, format: .currency(code: "USD").precision(.fractionLength(0)))
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundStyle(.primary)
                            if let source = competitor.otaRates.first {
                                Text(source.otaName)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    } else {
                        Text("--")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(.tertiary)
                        Text("Fetching...")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            if !competitor.otaRates.isEmpty && displayMode == .perRoomType {
                VStack(spacing: 0) {
                    ForEach(competitor.otaRates) { ota in
                        HStack {
                            Text(ota.otaName)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Spacer()
                            HStack(spacing: 4) {
                                Text(ota.rate, format: .currency(code: "USD").precision(.fractionLength(0)))
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.primary)
                                if ota.tax > 0 {
                                    Text("+\(ota.tax, format: .currency(code: "USD").precision(.fractionLength(0)))")
                                        .font(.system(size: 9))
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                        .padding(.vertical, 5)
                        .padding(.horizontal, 10)
                        if ota.id != competitor.otaRates.last?.id {
                            Rectangle()
                                .fill(Color.primary.opacity(0.04))
                                .frame(height: 0.5)
                                .padding(.leading, 10)
                        }
                    }
                }
                .background(Color.primary.opacity(0.03), in: .rect(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.primary.opacity(0.05), lineWidth: 0.5)
                )
            } else if !competitor.otaRates.isEmpty && displayMode == .average {
                HStack(spacing: 8) {
                    ForEach(competitor.otaRates.prefix(3)) { ota in
                        HStack(spacing: 3) {
                            Text(ota.otaName)
                                .font(.caption2)
                            Text(ota.rate, format: .currency(code: "USD").precision(.fractionLength(0)))
                                .font(.caption2.weight(.semibold))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.primary.opacity(0.05), in: .capsule)
                        .overlay(Capsule().strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5))
                        .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            }

            HStack {
                availabilityBadge
                Spacer()
                if !competitor.xoteloKey.isEmpty {
                    HStack(spacing: 3) {
                        Circle()
                            .fill(RevOwlTheme.positive)
                            .frame(width: 5, height: 5)
                        Text("Live")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(RevOwlTheme.positive)
                    }
                }
                Text("\(dateLabel) • 1 night")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(16)
        .glassCardStyle(cornerRadius: 20)
    }

    private var availabilityBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(availabilityColor)
                .frame(width: 6, height: 6)
                .shadow(color: availabilityColor.opacity(0.5), radius: 3)
            Text(competitor.availability)
                .font(.caption.weight(.medium))
                .foregroundStyle(availabilityColor)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(availabilityColor.opacity(0.12), in: .capsule)
    }

    private var availabilityColor: Color {
        switch competitor.availability {
        case "Sold Out": return RevOwlTheme.negative
        case "Limited": return .orange
        case "No Data": return .gray
        default: return RevOwlTheme.positive
        }
    }
}

struct CompetitorDetailSheet: View {
    let competitor: Competitor
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    private let today = Date.now
    private var dateLabel: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: today)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Text(competitor.name)
                        .font(.title2.bold())
                        .foregroundStyle(.primary)
                    HStack(spacing: 6) {
                        HStack(spacing: 1) {
                            ForEach(0..<competitor.stars, id: \.self) { _ in
                                Image(systemName: "star.fill")
                                    .font(.caption)
                                    .foregroundStyle(RevOwlTheme.gold)
                            }
                        }
                        Text("•")
                            .foregroundStyle(.tertiary)
                        Text(String(format: "%.1f mi away", competitor.distance))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    HStack(spacing: 4) {
                        Text("\(dateLabel) • 1 Night Stay")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        if !competitor.xoteloKey.isEmpty {
                            Text("•")
                                .foregroundStyle(.tertiary)
                            HStack(spacing: 2) {
                                Circle()
                                    .fill(RevOwlTheme.positive)
                                    .frame(width: 5, height: 5)
                                Text("Live Data")
                                    .font(.caption)
                                    .foregroundStyle(RevOwlTheme.positive)
                            }
                        }
                    }
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    infoCard(title: "Current Rate", value: competitor.currentRate.formatted(.currency(code: "USD").precision(.fractionLength(0))), icon: "dollarsign.circle.fill")
                    infoCard(title: "Rate Change", value: String(format: "%+.1f%%", competitor.rateChange), icon: "chart.line.uptrend.xyaxis")
                    infoCard(title: "Availability", value: competitor.availability, icon: "bed.double.fill")
                    infoCard(title: "OTA Presence", value: "\(competitor.otaPresence.count) sites", icon: "globe")
                }

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("OTA Rate Breakdown")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Spacer()
                        Button {
                            withAnimation(.snappy) { appState.toggleRateDisplayMode() }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: appState.rateDisplayMode == .perRoomType ? "list.bullet" : "chart.bar.fill")
                                    .font(.caption2)
                                Text(appState.rateDisplayMode == .perRoomType ? "Detailed" : "Average")
                                    .font(.caption.weight(.medium))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(RevOwlTheme.gold.opacity(0.15), in: .capsule)
                            .foregroundStyle(RevOwlTheme.gold)
                        }
                        .sensoryFeedback(.selection, trigger: appState.rateDisplayMode)
                    }

                    if competitor.otaRates.isEmpty {
                        ForEach(competitor.otaPresence, id: \.self) { ota in
                            HStack {
                                Text(ota)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(competitor.currentRate, format: .currency(code: "USD").precision(.fractionLength(0)))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                            }
                            .padding(14)
                            .glassCardStyle(cornerRadius: 14, elevation: .subtle)
                        }
                    } else {
                        ForEach(competitor.otaRates) { ota in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(ota.otaName)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(.primary)
                                    Text(ota.lastUpdated, style: .relative)
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(ota.rate, format: .currency(code: "USD").precision(.fractionLength(0)))
                                        .font(.system(size: 20, weight: .bold, design: .rounded))
                                        .foregroundStyle(.primary)
                                    if ota.tax > 0 {
                                        Text("+\(ota.tax, format: .currency(code: "USD").precision(.fractionLength(0))) tax")
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                            }
                            .padding(14)
                            .glassCardStyle(cornerRadius: 14, elevation: .subtle)
                        }

                        if appState.rateDisplayMode == .perRoomType {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Lowest")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                    Text(competitor.lowestOTARate, format: .currency(code: "USD").precision(.fractionLength(0)))
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(RevOwlTheme.positive)
                                }
                                Spacer()
                                VStack(spacing: 2) {
                                    Text("Average")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                    Text(competitor.averageOTARate, format: .currency(code: "USD").precision(.fractionLength(0)))
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(RevOwlTheme.gold)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("Highest")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                    Text(competitor.highestOTARate, format: .currency(code: "USD").precision(.fractionLength(0)))
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(RevOwlTheme.negative)
                                }
                            }
                            .padding(.horizontal, 4)
                        } else {
                            HStack {
                                Text("Average across OTAs")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(competitor.averageOTARate, format: .currency(code: "USD").precision(.fractionLength(0)))
                                    .font(.subheadline.bold())
                                    .foregroundStyle(RevOwlTheme.gold)
                            }
                            .padding(.horizontal, 4)
                        }
                    }
                }

                HStack(spacing: 6) {
                    Image(systemName: "link")
                        .font(.caption2)
                    Text("Rates sourced via Xotelo API • Real-time OTA data")
                        .font(.caption2)
                }
                .foregroundStyle(.tertiary)
            }
            .padding(20)
        }
        .navigationTitle("Competitor Detail")
        .navigationBarTitleDisplayMode(.inline)
        .deepGlassBackground()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
                    .foregroundStyle(RevOwlTheme.gold)
            }
        }
    }

    private func infoCard(title: String, value: String, icon: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(RevOwlTheme.gold)
                .shadow(color: RevOwlTheme.gold.opacity(0.3), radius: 4)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .glassCardStyle(cornerRadius: 16)
    }
}
