import SwiftUI
import Charts

struct DashboardView: View {
    @Environment(AppState.self) private var appState
    @State private var showOccupancyInput = false
    @State private var showRateManagement = false
    @State private var showDemandDetail = false
    @State private var animateAppear = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerSection
                    .staggeredAppear(index: 0, appear: animateAppear)
                statCardsSection
                RevenueImpactCard()
                    .staggeredAppear(index: 5, appear: animateAppear)
                demandFullWidthCard
                    .staggeredAppear(index: 6, appear: animateAppear)
                RateChartView(data: rateHistory)
                    .staggeredAppear(index: 7, appear: animateAppear)
                quickActionsSection
                    .staggeredAppear(index: 8, appear: animateAppear)
                alertFeedSection
                    .staggeredAppear(index: 9, appear: animateAppear)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .refreshable {
            await appState.refreshRates()
            appState.regenerateRecommendations()
        }
        .navigationTitle("Dashboard")
        .deepGlassBackground()
        .sheet(isPresented: $showOccupancyInput) {
            NavigationStack {
                OccupancyInputView()
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationContentInteraction(.scrolls)
        }
        .sheet(isPresented: $showRateManagement) {
            NavigationStack {
                RateManagementView()
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationContentInteraction(.scrolls)
        }
        .sheet(isPresented: $showDemandDetail) {
            NavigationStack {
                DemandDetailView()
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

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Good \(greeting)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(appState.hotel.name.isEmpty ? "Your Hotel" : appState.hotel.name)
                    .font(.title2.bold())
                    .foregroundStyle(.primary)
            }
            Spacer()
            Button {
                showDemandDetail = true
            } label: {
                DemandGaugeView(score: appState.demandScore, size: 64)
            }
            .sensoryFeedback(.impact(weight: .light), trigger: showDemandDetail)
        }
        .padding(.top, 8)
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        if hour < 12 { return "Morning" }
        if hour < 17 { return "Afternoon" }
        return "Evening"
    }

    private var statCardsSection: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            Button { showRateManagement = true } label: {
                StatCardView(
                    title: "Your Avg Rate", value: appState.avgRate.formatted(.currency(code: "USD").precision(.fractionLength(0))),
                    subtitle: rateSourceLabel, icon: "dollarsign.circle.fill", color: RevOwlTheme.gold
                )
            }
            .buttonStyle(GlassPressButtonStyle())
            .sensoryFeedback(.impact(weight: .light), trigger: showRateManagement)
            .staggeredAppear(index: 1, appear: animateAppear)

            StatCardView(
                title: "Competitor Avg", value: appState.competitorAvgRate > 0 ? appState.competitorAvgRate.formatted(.currency(code: "USD").precision(.fractionLength(0))) : "--",
                subtitle: appState.competitorAvgRate > 0 ? "\(appState.competitors.filter { $0.currentRate > 0 }.count) with rates" : "Fetching rates...", icon: "building.2.fill", color: .cyan
            )
            .staggeredAppear(index: 2, appear: animateAppear)

            StatCardView(
                title: "RevPAR", value: appState.revPAR.formatted(.currency(code: "USD").precision(.fractionLength(0))),
                subtitle: "+7.2% vs last week", icon: "chart.line.uptrend.xyaxis", color: RevOwlTheme.positive
            )
            .staggeredAppear(index: 3, appear: animateAppear)

            Button { showOccupancyInput = true } label: {
                occupancyStatCard
            }
            .buttonStyle(GlassPressButtonStyle())
            .sensoryFeedback(.impact(weight: .light), trigger: showOccupancyInput)
            .staggeredAppear(index: 4, appear: animateAppear)
        }
    }

    private var occupancyStatCard: some View {
        let rate = appState.overallOccupancy
        let color = RevOwlTheme.occupancyColor(for: rate)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "bed.double.fill")
                    .font(.caption)
                    .foregroundStyle(color)
                Spacer()
                Image(systemName: "pencil.circle.fill")
                    .font(.caption)
                    .foregroundStyle(RevOwlTheme.gold)
            }
            Text("\(Int(rate * 100))%")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
            VStack(alignment: .leading, spacing: 2) {
                Text("Occupancy")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Text("\(appState.totalRoomsSold)/\(appState.hotel.totalRooms) rooms")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCardStyle(cornerRadius: 20)
    }

    private var rateSourceLabel: String {
        let sources = Set(appState.hotelRates.map(\.source.rawValue))
        if sources.count == 1, let first = sources.first { return "via \(first)" }
        if sources.isEmpty { return "Not set" }
        return "\(sources.count) sources"
    }

    private var demandFullWidthCard: some View {
        Button {
            showDemandDetail = true
        } label: {
            HStack(spacing: 16) {
                DemandGaugeView(score: appState.demandScore, size: 100)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Demand Score")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(demandLabel)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(RevOwlTheme.demandColor(for: appState.demandScore).opacity(0.2), in: .capsule)
                            .foregroundStyle(RevOwlTheme.demandColor(for: appState.demandScore))
                    }

                    Text(demandSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineSpacing(2)
                        .lineLimit(3)

                    HStack(spacing: 12) {
                        demandSignalPill(icon: "airplane.arrival", label: "Flights")
                        demandSignalPill(icon: "ticket.fill", label: "Events")
                        demandSignalPill(icon: "building.2.fill", label: "Avail.")
                    }

                    Text("Tap for full breakdown")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(16)
            .glassCardStyle()
        }
        .buttonStyle(GlassPressButtonStyle())
        .sensoryFeedback(.impact(weight: .light), trigger: showDemandDetail)
    }

    private func demandSignalPill(icon: String, label: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 8))
            Text(label)
                .font(.system(size: 9, weight: .medium))
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color.primary.opacity(0.05), in: .capsule)
    }

    private var demandSummary: String {
        let score = appState.demandScore
        if score >= 70 {
            return "High demand detected — airport arrivals elevated, events driving bookings, competitor availability tightening."
        } else if score >= 40 {
            return "Moderate demand — some positive signals but market not under pressure. Monitor competitor moves."
        } else {
            return "Low demand period — consider competitive pricing to capture available bookings."
        }
    }

    private var demandLabel: String {
        let score = appState.demandScore
        if score < 40 { return "Low" }
        if score < 70 { return "Moderate" }
        return "High"
    }

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)
                .foregroundStyle(.primary)

            HStack(spacing: 12) {
                quickActionButton(icon: "square.and.pencil", title: "Update\nOccupancy", color: RevOwlTheme.gold) {
                    showOccupancyInput = true
                }
                quickActionButton(icon: "arrow.clockwise", title: "Refresh\nRates", color: .cyan) {
                    Task { await appState.refreshRates() }
                }
                quickActionButton(icon: "dollarsign.circle", title: "My\nRates", color: .green) {
                    showRateManagement = true
                }
            }
        }
    }

    private func quickActionButton(icon: String, title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
                    .shadow(color: color.opacity(0.4), radius: 4)
                Text(title)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .glassCardStyle(cornerRadius: 16, elevation: .subtle)
        }
        .buttonStyle(GlassPressButtonStyle())
        .sensoryFeedback(.impact(weight: .medium), trigger: appState.isRefreshingRates)
    }

    private var alertFeedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Alerts")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                if appState.unreadAlertCount > 0 {
                    Text("\(appState.unreadAlertCount) new")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(RevOwlTheme.gold.opacity(0.2), in: .capsule)
                        .foregroundStyle(RevOwlTheme.gold)
                }
            }

            if appState.alerts.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "bell.slash")
                        .foregroundStyle(.tertiary)
                    Text("No alerts yet. RevOwl is monitoring your market.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassCardStyle(cornerRadius: 14, elevation: .subtle)
            } else {
                ForEach(appState.alerts.prefix(3)) { alert in
                    alertRow(alert)
                }
            }
        }
    }

    private func alertRow(_ alert: AlertItem) -> some View {
        Button {
            withAnimation(.snappy) {
                appState.markAlertRead(alert.id)
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: alert.type.icon)
                    .font(.title3)
                    .foregroundStyle(alertColor(alert.type))
                    .frame(width: 36, height: 36)
                    .background(alertColor(alert.type).opacity(0.15), in: .rect(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 3) {
                    Text(alert.title)
                        .font(.subheadline.weight(alert.isRead ? .regular : .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(alert.sentAt, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                if !alert.isRead {
                    Circle()
                        .fill(RevOwlTheme.gold)
                        .frame(width: 8, height: 8)
                        .shadow(color: RevOwlTheme.gold.opacity(0.5), radius: 4)
                }
            }
            .padding(12)
            .glassCardStyle(cornerRadius: 14, elevation: .subtle)
        }
        .buttonStyle(GlassPressButtonStyle())
        .sensoryFeedback(.impact(weight: .light), trigger: alert.isRead)
    }

    private var rateHistory: [(day: String, yours: Double, competitor: Double)] {
        let yourAvg = appState.avgRate
        let compAvg = appState.competitorAvgRate
        guard yourAvg > 0 || compAvg > 0 else {
            return [("Mon", 0, 0), ("Tue", 0, 0), ("Wed", 0, 0), ("Thu", 0, 0), ("Fri", 0, 0), ("Sat", 0, 0), ("Sun", 0, 0)]
        }
        let days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        let variations: [Double] = [-0.03, -0.01, 0, 0.01, 0.03, 0.04, 0]
        return days.enumerated().map { i, day in
            let yVar = yourAvg * (1.0 + variations[i])
            let cVar = compAvg * (1.0 + variations[i] * 0.8)
            return (day, yVar.rounded(), cVar.rounded())
        }
    }

    private func alertColor(_ type: AlertType) -> Color {
        switch type {
        case .rateChange: return .cyan
        case .demandSurge: return RevOwlTheme.negative
        case .aiRecommendation: return .purple
        case .occupancyReminder: return .orange
        case .rateParity: return .yellow
        case .weeklySummary: return RevOwlTheme.positive
        }
    }
}
