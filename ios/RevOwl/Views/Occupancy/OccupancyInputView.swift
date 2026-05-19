import SwiftUI

struct OccupancyInputView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var editedEntries: [String: Int] = [:]

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                overallSummary

                VStack(alignment: .leading, spacing: 14) {
                    Text("Today's Rooms Sold")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    ForEach(appState.occupancyEntries) { entry in
                        roomTypeRow(entry)
                    }
                }

                VStack(spacing: 8) {
                    Text("Tip: Update daily for accurate dynamic pricing")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(20)
        }
        .navigationTitle("Update Occupancy")
        .navigationBarTitleDisplayMode(.inline)
        .deepGlassBackground()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
                    .foregroundStyle(.secondary)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    for (id, sold) in editedEntries {
                        appState.updateOccupancy(roomTypeId: id, roomsSold: sold)
                    }
                    dismiss()
                }
                .fontWeight(.semibold)
                .foregroundStyle(RevOwlTheme.gold)
                .sensoryFeedback(.success, trigger: editedEntries.count)
            }
        }
    }

    private var overallSummary: some View {
        let totalSold = appState.occupancyEntries.reduce(0) { result, entry in
            result + (editedEntries[entry.roomTypeId] ?? entry.roomsSold)
        }
        let total = appState.hotel.totalRooms

        return VStack(spacing: 10) {
            OccupancyRingView(sold: totalSold, total: total, size: 100)
            Text("Overall Occupancy")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
            Text("\(totalSold) of \(total) rooms sold")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .glassCardStyle()
    }

    private func roomTypeRow(_ entry: OccupancyEntry) -> some View {
        let currentSold = editedEntries[entry.roomTypeId] ?? entry.roomsSold
        let rate = Double(currentSold) / Double(max(entry.totalRooms, 1))
        let color = RevOwlTheme.occupancyColor(for: rate)

        return VStack(spacing: 10) {
            HStack {
                Text(entry.roomTypeName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
                Text("\(currentSold)/\(entry.totalRooms)")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(color)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(color.opacity(0.1))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.6), color],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * rate)
                        .shadow(color: color.opacity(0.3), radius: 4)
                        .animation(.snappy, value: currentSold)
                }
            }
            .frame(height: 6)

            HStack(spacing: 12) {
                Button {
                    let newValue = max(0, currentSold - 1)
                    editedEntries[entry.roomTypeId] = newValue
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .sensoryFeedback(.impact(weight: .light), trigger: currentSold)

                Slider(
                    value: Binding(
                        get: { Double(currentSold) },
                        set: { editedEntries[entry.roomTypeId] = Int($0) }
                    ),
                    in: 0...Double(entry.totalRooms),
                    step: 1
                )
                .tint(color)

                Button {
                    let newValue = min(entry.totalRooms, currentSold + 1)
                    editedEntries[entry.roomTypeId] = newValue
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(color)
                }
                .sensoryFeedback(.impact(weight: .light), trigger: currentSold)
            }
        }
        .padding(14)
        .glassCardStyle(cornerRadius: 16, elevation: .subtle)
    }
}
