import SwiftUI

struct NotificationSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("notif_rateChanges") private var rateChanges = true
    @AppStorage("notif_demandSurges") private var demandSurges = true
    @AppStorage("notif_aiRecommendations") private var aiRecommendations = true
    @AppStorage("notif_occupancyReminders") private var occupancyReminders = true
    @AppStorage("notif_rateParity") private var rateParity = true
    @AppStorage("notif_weeklySummary") private var weeklySummary = true
    @AppStorage("notif_quietHoursEnabled") private var quietHoursEnabled = false
    @AppStorage("notif_quietStart") private var quietStartHour: Int = 22
    @AppStorage("notif_quietEnd") private var quietEndHour: Int = 7
    @AppStorage("notif_sensitivity") private var sensitivity: Double = 0.5

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Alert Types")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .padding(.horizontal, 16)

                    VStack(spacing: 0) {
                        notifToggle(icon: "arrow.up.arrow.down.circle.fill", title: "Rate Changes", subtitle: "When competitors adjust their rates", isOn: $rateChanges, color: .cyan)
                        glassDivider
                        notifToggle(icon: "flame.fill", title: "Demand Surges", subtitle: "When demand score spikes above threshold", isOn: $demandSurges, color: RevOwlTheme.negative)
                        glassDivider
                        notifToggle(icon: "brain.fill", title: "AI Recommendations", subtitle: "New dynamic pricing suggestions", isOn: $aiRecommendations, color: .purple)
                        glassDivider
                        notifToggle(icon: "bell.badge.fill", title: "Occupancy Reminders", subtitle: "Daily prompts to update room counts", isOn: $occupancyReminders, color: .orange)
                        glassDivider
                        notifToggle(icon: "exclamationmark.triangle.fill", title: "Rate Parity Warnings", subtitle: "OTA pricing discrepancies detected", isOn: $rateParity, color: .yellow)
                        glassDivider
                        notifToggle(icon: "chart.bar.doc.horizontal.fill", title: "Weekly Summary", subtitle: "Weekly digest with trends and insights", isOn: $weeklySummary, color: RevOwlTheme.positive)
                    }
                    .glassCardStyle()
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Sensitivity")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .padding(.horizontal, 16)

                    VStack(spacing: 12) {
                        HStack {
                            Text("Alert Threshold")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.primary)
                            Spacer()
                            Text(sensitivityLabel)
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(RevOwlTheme.gold.opacity(0.15), in: .capsule)
                                .foregroundStyle(RevOwlTheme.gold)
                        }

                        Slider(value: $sensitivity, in: 0...1)
                            .tint(RevOwlTheme.gold)

                        HStack {
                            Text("Fewer alerts")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                            Spacer()
                            Text("More alerts")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }

                        Text("Controls how significant a change must be before you're notified. Lower sensitivity means only major changes trigger alerts.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineSpacing(2)
                    }
                    .padding(16)
                    .glassCardStyle()
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Quiet Hours")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .padding(.horizontal, 16)

                    VStack(spacing: 0) {
                        Toggle(isOn: $quietHoursEnabled) {
                            HStack(spacing: 12) {
                                Image(systemName: "moon.fill")
                                    .font(.title3)
                                    .foregroundStyle(.indigo)
                                    .frame(width: 32)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Enable Quiet Hours")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(.primary)
                                    Text("Silence non-urgent notifications")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .tint(RevOwlTheme.gold)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)

                        if quietHoursEnabled {
                            glassDivider

                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("From")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Picker("Start", selection: $quietStartHour) {
                                        ForEach(0..<24, id: \.self) { hour in
                                            Text(formatHour(hour)).tag(hour)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .tint(RevOwlTheme.gold)
                                }

                                Spacer()

                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("To")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Picker("End", selection: $quietEndHour) {
                                        ForEach(0..<24, id: \.self) { hour in
                                            Text(formatHour(hour)).tag(hour)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .tint(RevOwlTheme.gold)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                    }
                    .glassCardStyle()
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .deepGlassBackground()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
                    .foregroundStyle(RevOwlTheme.gold)
            }
        }
        .sensoryFeedback(.selection, trigger: quietHoursEnabled)
    }

    private var sensitivityLabel: String {
        if sensitivity < 0.33 { return "Low" }
        if sensitivity < 0.66 { return "Medium" }
        return "High"
    }

    private func formatHour(_ hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        var components = DateComponents()
        components.hour = hour
        let date = Calendar.current.date(from: components) ?? .now
        return formatter.string(from: date)
    }

    private var glassDivider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.05))
            .frame(height: 0.5)
            .padding(.leading, 56)
    }

    private func notifToggle(icon: String, title: String, subtitle: String, isOn: Binding<Bool>, color: Color) -> some View {
        Toggle(isOn: isOn) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .tint(RevOwlTheme.gold)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
