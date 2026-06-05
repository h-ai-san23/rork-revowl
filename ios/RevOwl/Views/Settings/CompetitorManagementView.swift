import SwiftUI
import MapKit
import CoreLocation

struct CompetitorManagementView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var searchQuery: String = ""
    @State private var searchResults: [DiscoveredCompetitor] = []
    @State private var isSearching: Bool = false
    @State private var addingId: String? = nil
    @State private var pendingDelete: Competitor? = nil
    @State private var errorMessage: String? = nil
    @State private var searchTask: Task<Void, Never>? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                searchSection
                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(RevOwlTheme.negative)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if !searchResults.isEmpty {
                    searchResultsSection
                }
                trackedSection
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .navigationTitle("Competitors")
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        .deepGlassBackground()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
                    .foregroundStyle(RevOwlTheme.gold)
            }
        }
        .alert("Remove Competitor", isPresented: .init(
            get: { pendingDelete != nil },
            set: { if !$0 { pendingDelete = nil } }
        )) {
            Button("Remove", role: .destructive) {
                if let competitor = pendingDelete {
                    appState.removeCompetitor(competitor.id)
                }
                pendingDelete = nil
            }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        } message: {
            Text("Stop tracking \(pendingDelete?.name ?? "this hotel")? You can add it back anytime.")
        }
    }

    // MARK: - Search

    private var searchSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Add a Competitor")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search hotels nearby", text: $searchQuery)
                    .foregroundStyle(.primary)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .onSubmit { triggerSearch() }
                    .onChange(of: searchQuery) { _, _ in scheduleSearch() }
                if isSearching {
                    ProgressView()
                        .controlSize(.small)
                        .tint(RevOwlTheme.gold)
                } else if !searchQuery.isEmpty {
                    Button {
                        searchQuery = ""
                        searchResults = []
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .padding(14)
            .glassCardStyle(cornerRadius: 14, elevation: .subtle)

            Text("Searches around your hotel's location. Tap a result to start tracking its live rates.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var searchResultsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Results")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            VStack(spacing: 10) {
                ForEach(searchResults) { result in
                    let isTracked = isAlreadyTracked(result)
                    Button {
                        Task { await add(result) }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "building.2.fill")
                                .font(.title3)
                                .foregroundStyle(RevOwlTheme.gold)
                                .frame(width: 36)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(result.name)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                Text(resultSubtitle(result))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            if addingId == result.id {
                                ProgressView()
                                    .controlSize(.small)
                                    .tint(RevOwlTheme.gold)
                            } else if isTracked {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(RevOwlTheme.positive)
                            } else {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(RevOwlTheme.gold)
                            }
                        }
                        .padding(14)
                        .glassCardStyle(cornerRadius: 14, elevation: .subtle)
                    }
                    .buttonStyle(GlassPressButtonStyle())
                    .disabled(isTracked || addingId != nil)
                }
            }
        }
    }

    // MARK: - Tracked

    private var trackedSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Tracked Hotels")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
                Text("\(appState.competitors.count)/\(appState.currentTier.competitorLimit)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(RevOwlTheme.gold)
            }

            if appState.competitors.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "building.2")
                        .font(.title)
                        .foregroundStyle(.tertiary)
                    Text("No competitors tracked yet")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                    Text("Search above to add hotels you want to monitor.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(28)
                .glassCardStyle(cornerRadius: 16, elevation: .subtle)
            } else {
                VStack(spacing: 10) {
                    ForEach(appState.competitors) { competitor in
                        HStack(spacing: 12) {
                            HStack(spacing: 1) {
                                ForEach(0..<max(competitor.stars, 1), id: \.self) { _ in
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 8))
                                        .foregroundStyle(RevOwlTheme.gold)
                                }
                            }
                            .frame(width: 44, alignment: .leading)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(competitor.name)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                HStack(spacing: 5) {
                                    Text(String(format: "%.1f mi", competitor.distance))
                                    if !competitor.xoteloKey.isEmpty {
                                        Text("•")
                                        HStack(spacing: 2) {
                                            Circle()
                                                .fill(RevOwlTheme.positive)
                                                .frame(width: 5, height: 5)
                                            Text("Live")
                                                .foregroundStyle(RevOwlTheme.positive)
                                        }
                                    } else {
                                        Text("•")
                                        Text("Resolving…")
                                            .foregroundStyle(.orange)
                                    }
                                }
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button {
                                pendingDelete = competitor
                            } label: {
                                Image(systemName: "trash")
                                    .font(.subheadline)
                                    .foregroundStyle(RevOwlTheme.negative)
                                    .frame(width: 36, height: 36)
                                    .background(RevOwlTheme.negative.opacity(0.12), in: .circle)
                            }
                            .sensoryFeedback(.warning, trigger: pendingDelete?.id)
                        }
                        .padding(14)
                        .glassCardStyle(cornerRadius: 14, elevation: .subtle)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func resultSubtitle(_ result: DiscoveredCompetitor) -> String {
        var parts: [String] = []
        if result.distance > 0 {
            parts.append(String(format: "%.1f mi away", result.distance))
        }
        if let address = result.address, !address.isEmpty {
            parts.append(address)
        }
        return parts.isEmpty ? "Nearby hotel" : parts.joined(separator: " • ")
    }

    private func isAlreadyTracked(_ result: DiscoveredCompetitor) -> Bool {
        appState.competitors.contains { existing in
            existing.name.caseInsensitiveCompare(result.name) == .orderedSame
                || (abs(existing.latitude - result.latitude) < 0.0005
                    && abs(existing.longitude - result.longitude) < 0.0005)
        }
    }

    private func add(_ result: DiscoveredCompetitor) async {
        guard addingId == nil else { return }
        errorMessage = nil
        guard appState.competitors.count < appState.currentTier.competitorLimit else {
            errorMessage = "You've reached your plan's limit of \(appState.currentTier.competitorLimit) competitors. Upgrade to track more."
            return
        }
        addingId = result.id
        let added = await appState.addCompetitor(result)
        addingId = nil
        if !added {
            errorMessage = "Couldn't add that hotel — it may already be tracked or your plan limit was reached."
        }
    }

    private func scheduleSearch() {
        searchTask?.cancel()
        let query = searchQuery.trimmingCharacters(in: .whitespaces)
        guard query.count >= 3 else {
            searchResults = []
            isSearching = false
            return
        }
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(450))
            if Task.isCancelled { return }
            await performSearch(query: query)
        }
    }

    private func triggerSearch() {
        searchTask?.cancel()
        let query = searchQuery.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return }
        Task { await performSearch(query: query) }
    }

    private func performSearch(query: String) async {
        isSearching = true
        errorMessage = nil

        let center = await searchCenter()
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "\(query) hotel"
        if let center {
            request.region = MKCoordinateRegion(
                center: center,
                span: MKCoordinateSpan(latitudeDelta: 0.15, longitudeDelta: 0.15)
            )
        }

        do {
            let search = MKLocalSearch(request: request)
            let response = try await search.start()
            if Task.isCancelled { return }

            var results: [DiscoveredCompetitor] = []
            for item in response.mapItems {
                guard let name = item.name else { continue }
                let coord = item.placemark.coordinate
                let dist: Double = center.map { distanceMiles(from: $0, to: coord) } ?? 0
                let address = [item.placemark.thoroughfare, item.placemark.locality, item.placemark.administrativeArea]
                    .compactMap { $0 }
                    .joined(separator: ", ")
                results.append(DiscoveredCompetitor(
                    name: name,
                    latitude: coord.latitude,
                    longitude: coord.longitude,
                    distance: dist,
                    address: address.isEmpty ? nil : address
                ))
            }
            results.sort { $0.distance < $1.distance }
            searchResults = Array(results.prefix(15))
            if searchResults.isEmpty {
                errorMessage = "No hotels found for \"\(query)\". Try a different name."
            }
        } catch {
            if !Task.isCancelled {
                errorMessage = "Search failed. Check your connection and try again."
                searchResults = []
            }
        }
        isSearching = false
    }

    private func searchCenter() async -> CLLocationCoordinate2D? {
        if appState.hotel.latitude != 0 || appState.hotel.longitude != 0 {
            return CLLocationCoordinate2D(latitude: appState.hotel.latitude, longitude: appState.hotel.longitude)
        }
        guard !appState.hotel.address.isEmpty else { return nil }
        let geocoder = CLGeocoder()
        return try? await geocoder.geocodeAddressString(appState.hotel.address).first?.location?.coordinate
    }

    private func distanceMiles(from a: CLLocationCoordinate2D, to b: CLLocationCoordinate2D) -> Double {
        let locA = CLLocation(latitude: a.latitude, longitude: a.longitude)
        let locB = CLLocation(latitude: b.latitude, longitude: b.longitude)
        return locA.distance(from: locB) / 1609.34
    }
}
