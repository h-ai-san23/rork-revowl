import MapKit
import SwiftUI

struct PlaceResult: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let address: String?
    let city: String?
    let country: String?
    let countryCode: String?
    let latitude: Double
    let longitude: Double
    let timeZone: String?
    let phone: String?
    let website: String?
}

/// Finds the property with Apple Maps (or accepts a manual name) and creates it on the server.
struct PropertyStep: View {
    @Environment(AppModel.self) private var app
    @State private var query = ""
    @State private var results: [PlaceResult] = []
    @State private var selected: PlaceResult?
    @State private var isSearching = false
    @State private var isWorking = false
    @State private var errorText: String?
    @State private var searchTask: Task<Void, Never>?
    @State private var showInvite = false
    @State private var inviteCode = ""

    private var canContinue: Bool { selected != nil || query.trimmed.count >= 2 }

    var body: some View {
        StepScaffold(
            orev: isWorking ? .thinking : (errorText != nil ? .errorRecovery : .listening),
            title: "Which property is yours?",
            message: "Search for your hotel. I'll use its location to find nearby competitors and local events.",
            primaryTitle: selected == nil ? "Use “\(query.trimmed.isEmpty ? "this name" : query.trimmed)”" : "This is my property",
            primaryEnabled: canContinue,
            isWorking: isWorking,
            secondaryTitle: (app.me?.properties.isEmpty ?? true) ? "I have an invite code" : "Back to my property",
            onPrimary: { Task { await create() } },
            onSecondary: secondary
        ) {
            AppTextField(
                placeholder: "Hotel name and city",
                text: $query,
                id: "property.search",
                icon: "magnifyingglass",
                contentType: .organizationName,
                capitalization: .words,
                submitLabel: .search,
                isBusy: isSearching,
                onSubmit: { scheduleSearch(immediate: true) }
            )
            .onChange(of: query) { _, _ in
                if selected?.name != query { selected = nil }
                scheduleSearch(immediate: false)
            }

            if let selected {
                PlaceRow(place: selected, isSelected: true)
                    .card(padding: 14, fill: Palette.tealSoft)
            } else if !results.isEmpty {
                VStack(spacing: 0) {
                    ForEach(results) { place in
                        Button {
                            selected = place
                            query = place.name
                            UIApplication.dismissKeyboard()
                        } label: {
                            PlaceRow(place: place, isSelected: false)
                                .padding(.vertical, 10)
                                .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        if place.id != results.last?.id { Divider().overlay(Palette.hairline) }
                    }
                }
                .card(padding: 12)
            } else if query.trimmed.count >= 3 && !isSearching {
                Text("No matches on Apple Maps. You can continue with the name you typed and add the details yourself.")
                    .font(.footnote)
                    .foregroundStyle(Palette.inkSecondary)
            }

            if let errorText {
                InlineMessage(kind: .error, text: errorText)
            }
        }
        .alert("Join a property", isPresented: $showInvite) {
            TextField("Invite code", text: $inviteCode)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .accessibilityIdentifier("property.inviteCode")
            Button("Join") { Task { await join() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Enter the code the property owner shared with you.")
        }
    }

    private var secondary: () -> Void {
        if app.me?.properties.isEmpty ?? true {
            return { showInvite = true }
        }
        return {
            guard let first = app.me?.properties.first else { return }
            Task { try? await app.selectProperty(first.propertyId) }
        }
    }

    private func scheduleSearch(immediate: Bool) {
        searchTask?.cancel()
        let q = query.trimmed
        guard q.count >= 3, selected == nil else {
            if q.count < 3 { results = [] }
            return
        }
        searchTask = Task {
            if !immediate { try? await Task.sleep(for: .milliseconds(350)) }
            guard !Task.isCancelled else { return }
            await search(q)
        }
    }

    private func search(_ q: String) async {
        isSearching = true
        defer { isSearching = false }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = q
        request.resultTypes = .pointOfInterest
        request.pointOfInterestFilter = MKPointOfInterestFilter(including: [.hotel])
        do {
            let response = try await MKLocalSearch(request: request).start()
            guard !Task.isCancelled else { return }
            results = response.mapItems.prefix(8).map { item in
                let reps = item.addressRepresentations
                return PlaceResult(
                    name: item.name ?? q,
                    address: item.address?.fullAddress ?? item.address?.shortAddress,
                    city: reps?.cityName,
                    country: reps?.regionName,
                    countryCode: reps?.region?.identifier,
                    latitude: item.location.coordinate.latitude,
                    longitude: item.location.coordinate.longitude,
                    timeZone: item.timeZone?.identifier,
                    phone: item.phoneNumber,
                    website: item.url?.absoluteString
                )
            }
        } catch {
            if !Task.isCancelled { results = [] }
        }
    }

    private func create() async {
        isWorking = true
        errorText = nil
        defer { isWorking = false }
        var body: [String: JSONValue] = [
            "timeZone": .string(selected?.timeZone ?? TimeZone.current.identifier),
        ]
        if let place = selected {
            body["name"] = .string(place.name)
            body["address"] = .from(place.address)
            body["city"] = .from(place.city)
            body["country"] = .from(place.country)
            body["countryCode"] = .from(place.countryCode)
            body["latitude"] = .number(place.latitude)
            body["longitude"] = .number(place.longitude)
            body["phone"] = .from(place.phone)
            body["website"] = .from(place.website)
            body["currency"] = .string(CurrencyOptions.forRegion(place.countryCode) ?? Locale.current.currency?.identifier ?? "USD")
        } else {
            body["name"] = .string(query.trimmed)
            body["currency"] = .string(Locale.current.currency?.identifier ?? "USD")
        }
        do {
            try await app.createProperty(body)
        } catch {
            errorText = error.userMessage
        }
    }

    private func join() async {
        isWorking = true
        errorText = nil
        defer { isWorking = false }
        do {
            try await app.acceptInvite(inviteCode)
        } catch {
            errorText = error.userMessage
        }
    }
}

private struct PlaceRow: View {
    let place: PlaceResult
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "building.2")
                .font(.title3)
                .foregroundStyle(Palette.teal)
                .frame(width: 32)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(place.name).font(.headline).foregroundStyle(Palette.ink)
                if let address = place.address {
                    Text(address).font(.footnote).foregroundStyle(Palette.inkSecondary).lineLimit(2)
                }
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
