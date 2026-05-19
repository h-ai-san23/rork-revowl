import SwiftUI

struct AlertsView: View {
    @Environment(AppState.self) private var appState
    @State private var filter: AlertType?

    private var filteredAlerts: [AlertItem] {
        guard let filter else { return appState.alerts }
        return appState.alerts.filter { $0.type == filter }
    }

    private var upcomingEvents: [LocalEvent] {
        appState.localEvents
            .filter { $0.date >= Calendar.current.startOfDay(for: .now) }
            .sorted { $0.date < $1.date }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                eventsDashboard

                filterBar

                if filteredAlerts.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "bell.slash")
                            .font(.system(size: 40))
                            .foregroundStyle(.tertiary)
                        Text("No Alerts")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text("You're all caught up.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 40)
                } else {
                    ForEach(filteredAlerts) { alert in
                        AlertRow(alert: alert) {
                            withAnimation(.snappy) {
                                appState.markAlertRead(alert.id)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .navigationTitle("Alerts")
        .deepGlassBackground()
        .task {
            if appState.localEvents.isEmpty && !appState.hotel.address.isEmpty {
                await appState.refreshLocalEvents()
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Read All") {
                    withAnimation(.snappy) {
                        for alert in appState.alerts where !alert.isRead {
                            appState.markAlertRead(alert.id)
                        }
                    }
                }
                .font(.subheadline)
                .foregroundStyle(RevOwlTheme.gold)
                .disabled(appState.unreadAlertCount == 0)
            }
        }
        .sensoryFeedback(.selection, trigger: filter)
    }

    private var eventsDashboard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "calendar.badge.clock")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(RevOwlTheme.gold)
                Text("Local Demand Events")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
                Button {
                    Task { await appState.refreshLocalEvents() }
                } label: {
                    if appState.isRefreshingEvents {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.subheadline)
                            .foregroundStyle(RevOwlTheme.gold)
                    }
                }
                .disabled(appState.isRefreshingEvents)
            }

            if let stamp = appState.lastEventsRefresh {
                Text("Updated \(stamp, style: .relative) ago • Within ~25 mi of \(shortAddress)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            } else if !appState.hotel.address.isEmpty {
                Text("Searches the live web for events that drive hotel demand.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            if let err = appState.eventsErrorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if upcomingEvents.isEmpty {
                if appState.isRefreshingEvents {
                    HStack(spacing: 10) {
                        ProgressView().controlSize(.small)
                        Text("Searching the web for upcoming events…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
                } else {
                    Text("No high-demand events found nearby. Tap refresh to search again.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                }
            } else {
                VStack(spacing: 8) {
                    ForEach(upcomingEvents.prefix(6)) { event in
                        EventRow(event: event)
                    }
                }
            }
        }
        .padding(14)
        .glassCardStyle(cornerRadius: 18, elevation: .primary)
    }

    private var shortAddress: String {
        let parts = appState.hotel.address.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        if parts.count >= 2 { return parts.dropFirst().prefix(1).joined() }
        return appState.hotel.address
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Button("All") { filter = nil }
                    .buttonStyle(GlassChipStyle(isActive: filter == nil))
                Button("Rate Changes") { filter = .rateChange }
                    .buttonStyle(GlassChipStyle(isActive: filter == .rateChange))
                Button("Demand") { filter = .demandSurge }
                    .buttonStyle(GlassChipStyle(isActive: filter == .demandSurge))
                Button("AI Recs") { filter = .aiRecommendation }
                    .buttonStyle(GlassChipStyle(isActive: filter == .aiRecommendation))
                Button("Parity") { filter = .rateParity }
                    .buttonStyle(GlassChipStyle(isActive: filter == .rateParity))
            }
        }
        .contentMargins(.horizontal, 0)
        .padding(.top, 4)
    }
}

struct EventRow: View {
    let event: LocalEvent

    private var impactColor: Color {
        switch event.impact {
        case .high: return RevOwlTheme.demandRed
        case .medium: return RevOwlTheme.demandAmber
        case .low: return RevOwlTheme.demandGreen
        }
    }

    var body: some View {
        let content = HStack(spacing: 12) {
            VStack(spacing: 2) {
                Text(event.date, format: .dateTime.month(.abbreviated))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(event.date, format: .dateTime.day())
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)
            }
            .frame(width: 44)

            Image(systemName: event.category.icon)
                .font(.subheadline)
                .foregroundStyle(impactColor)
                .frame(width: 32, height: 32)
                .background(impactColor.opacity(0.15), in: .rect(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 3) {
                Text(event.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                HStack(spacing: 6) {
                    Text(event.venue)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    if event.expectedAttendance > 0 {
                        Text("•")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Text("\(event.expectedAttendance.formatted()) expected")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer(minLength: 4)

            Text(event.impact.rawValue)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(impactColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(impactColor.opacity(0.15), in: .capsule)
        }
        .padding(10)
        .background(Color.white.opacity(0.04), in: .rect(cornerRadius: 12))

        if let url = URL(string: event.sourceURL), !event.sourceURL.isEmpty {
            Link(destination: url) { content }
                .buttonStyle(GlassPressButtonStyle())
        } else {
            content
        }
    }
}

struct AlertRow: View {
    let alert: AlertItem
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: alert.type.icon)
                    .font(.title3)
                    .foregroundStyle(iconColor)
                    .frame(width: 40, height: 40)
                    .background(iconColor.opacity(0.15), in: .rect(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(alert.title)
                            .font(.subheadline.weight(alert.isRead ? .regular : .semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Spacer()
                        if !alert.isRead {
                            Circle()
                                .fill(RevOwlTheme.gold)
                                .frame(width: 8, height: 8)
                                .shadow(color: RevOwlTheme.gold.opacity(0.5), radius: 4)
                        }
                    }
                    Text(alert.message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Text(alert.sentAt, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(14)
            .glassCardStyle(cornerRadius: 16, elevation: .subtle)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(alert.isRead ? .clear : RevOwlTheme.gold.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(GlassPressButtonStyle())
        .sensoryFeedback(.impact(weight: .light), trigger: alert.isRead)
    }

    private var iconColor: Color {
        switch alert.type {
        case .rateChange: return .cyan
        case .demandSurge: return RevOwlTheme.negative
        case .aiRecommendation: return .purple
        case .occupancyReminder: return .orange
        case .rateParity: return .yellow
        case .weeklySummary: return RevOwlTheme.positive
        }
    }
}
