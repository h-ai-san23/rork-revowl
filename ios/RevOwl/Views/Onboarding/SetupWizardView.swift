import SwiftUI
import MapKit
import UserNotifications

struct SetupWizardView: View {
    let onComplete: () -> Void
    @Environment(AppState.self) private var appState
    @State private var currentStep: Int = 0
    @State private var hotelName: String = ""
    @State private var hotelAddress: String = ""
    @State private var totalRooms: String = ""
    @State private var starRating: Int = 3
    @State private var propertyType: PropertyType = .boutique
    @State private var roomTypes: [RoomType] = [
        RoomType(name: "King", baseRate: 169, floorRate: 129, count: 30)
    ]
    @State private var selectedCompetitors: Set<String> = []
    @State private var discoveredCompetitors: [DiscoveredCompetitor] = []
    @State private var isSearchingCompetitors: Bool = false
    @State private var hotelCoordinate: CLLocationCoordinate2D?
    @State private var pricingStrategy: PricingStrategy = .balanced
    @State private var riskTolerance: Double = 0.5
    @State private var maxAdjustment: Double = 0.15
    @State private var enableRateAlerts: Bool = true
    @State private var enableDemandAlerts: Bool = true
    @State private var enableRecommendationAlerts: Bool = true
    @State private var enableOccupancyReminders: Bool = true
    @State private var notificationPermissionGranted: Bool = false
    @State private var notificationPermissionRequested: Bool = false
    @State private var showDuplicateHotelAlert: Bool = false

    @State private var addressSuggestions: [MKLocalSearchCompletion] = []
    @State private var searchCompleter = AddressSearchCompleter()
    @State private var showAddressSuggestions: Bool = false

    @State private var hotelSuggestions: [HotelSuggestion] = []
    @State private var isSearchingHotels: Bool = false
    @State private var showHotelSuggestions: Bool = false
    @State private var hotelSearchTask: Task<Void, Never>? = nil
    @State private var didPickHotel: Bool = false

    @FocusState private var focusedField: SetupField?

    private let totalSteps = 6

    nonisolated enum SetupField: Hashable {
        case hotelName, hotelAddress, totalRooms
        case roomName(String), roomBaseRate(String), roomFloorRate(String), roomCount(String)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                headerBar
                progressBar

                TabView(selection: $currentStep) {
                    hotelDetailsStep.tag(0)
                    roomTypesStep.tag(1)
                    competitorStep.tag(2)
                    strategyStep.tag(3)
                    notificationPermissionStep.tag(4)
                    notificationPreferencesStep.tag(5)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.smooth, value: currentStep)

                navigationButtons
            }
            .deepGlassBackground()
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        focusedField = nil
                    }
                    .fontWeight(.semibold)
                }
            }
            .onTapGesture {
                focusedField = nil
            }
            .sensoryFeedback(.selection, trigger: currentStep)
            .alert("Hotel Already Registered", isPresented: $showDuplicateHotelAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("This hotel already has an active account on this device. Each hotel is limited to one account. To add additional users, go to Settings in the existing account.")
            }
            .onChange(of: searchCompleter.results) { _, newResults in
                addressSuggestions = newResults
                showAddressSuggestions = !newResults.isEmpty
            }
        }
    }

    private var headerBar: some View {
        VStack(spacing: 4) {
            Text("Step \(currentStep + 1) of \(totalSteps)")
                .font(.caption.weight(.medium))
                .foregroundStyle(RevOwlTheme.gold.opacity(0.9))
            Text(stepTitle)
                .font(.title3.bold())
                .foregroundStyle(.white)
        }
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    private var stepTitle: String {
        switch currentStep {
        case 0: return "Hotel Details"
        case 1: return "Room Types"
        case 2: return "Competitor Discovery"
        case 3: return "Pricing Strategy"
        case 4: return "Notifications"
        case 5: return "Preferences"
        default: return ""
        }
    }

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.06))
                    .frame(height: 4)
                Capsule()
                    .fill(RevOwlTheme.goldGradient)
                    .frame(width: geo.size.width * (CGFloat(currentStep + 1) / CGFloat(totalSteps)), height: 4)
                    .shadow(color: RevOwlTheme.gold.opacity(0.3), radius: 4)
                    .animation(.snappy, value: currentStep)
            }
        }
        .frame(height: 4)
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
    }

    private var hotelDetailsStep: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Hotel Name")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.85))
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.white.opacity(0.5))
                        TextField("Search for your hotel...", text: $hotelName)
                            .textContentType(.organizationName)
                            .autocorrectionDisabled()
                            .focused($focusedField, equals: .hotelName)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .hotelAddress }
                        if isSearchingHotels {
                            ProgressView()
                                .controlSize(.small)
                                .tint(RevOwlTheme.gold)
                        }
                    }
                    .padding(14)
                    .background(.ultraThinMaterial, in: .rect(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(.white.opacity(0.08), lineWidth: 0.5)
                    )
                    .onChange(of: hotelName) { _, newValue in
                        if didPickHotel {
                            didPickHotel = false
                            return
                        }
                        scheduleHotelSearch(query: newValue)
                    }

                    if showHotelSuggestions && !hotelSuggestions.isEmpty {
                        VStack(spacing: 0) {
                            ForEach(hotelSuggestions) { suggestion in
                                Button {
                                    pickHotel(suggestion)
                                } label: {
                                    HStack(spacing: 10) {
                                        Image(systemName: "building.2.fill")
                                            .font(.subheadline)
                                            .foregroundStyle(RevOwlTheme.gold)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(suggestion.name)
                                                .font(.subheadline)
                                                .foregroundStyle(.white)
                                                .lineLimit(1)
                                            if !suggestion.address.isEmpty {
                                                Text(suggestion.address)
                                                    .font(.caption)
                                                    .foregroundStyle(.white.opacity(0.65))
                                                    .lineLimit(1)
                                            }
                                        }
                                        Spacer()
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                }
                                if suggestion.id != hotelSuggestions.last?.id {
                                    Rectangle()
                                        .fill(.white.opacity(0.05))
                                        .frame(height: 0.5)
                                        .padding(.leading, 14)
                                }
                            }
                        }
                        .background(.ultraThinMaterial, in: .rect(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(.white.opacity(0.08), lineWidth: 0.5)
                        )
                    }

                    Text("Type your hotel's name and pick it from the list — we'll fill in the address and link it to live rate data automatically.")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.55))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Address")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.85))
                    TextField("Start typing to search...", text: $hotelAddress)
                        .textContentType(.fullStreetAddress)
                        .focused($focusedField, equals: .hotelAddress)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .totalRooms }
                        .padding(14)
                        .background(.ultraThinMaterial, in: .rect(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(.white.opacity(0.08), lineWidth: 0.5)
                        )
                        .onChange(of: hotelAddress) { _, newValue in
                            searchCompleter.search(query: newValue)
                            showAddressSuggestions = !newValue.isEmpty
                        }

                    if showAddressSuggestions && !addressSuggestions.isEmpty {
                        VStack(spacing: 0) {
                            ForEach(addressSuggestions.prefix(5), id: \.self) { suggestion in
                                Button {
                                    hotelAddress = [suggestion.title, suggestion.subtitle]
                                        .filter { !$0.isEmpty }
                                        .joined(separator: ", ")
                                    showAddressSuggestions = false
                                    addressSuggestions = []
                                    searchCompleter.search(query: "")
                                    focusedField = nil
                                } label: {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(suggestion.title)
                                            .font(.subheadline)
                                            .foregroundStyle(.white)
                                            .lineLimit(1)
                                        if !suggestion.subtitle.isEmpty {
                                            Text(suggestion.subtitle)
                                                .font(.caption)
                                                .foregroundStyle(.white.opacity(0.65))
                                                .lineLimit(1)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                }
                                if suggestion != addressSuggestions.prefix(5).last {
                                    Rectangle()
                                        .fill(.white.opacity(0.05))
                                        .frame(height: 0.5)
                                        .padding(.leading, 14)
                                }
                            }
                        }
                        .background(.ultraThinMaterial, in: .rect(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(.white.opacity(0.08), lineWidth: 0.5)
                        )
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Total Rooms")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.85))
                    TextField("e.g. 86", text: $totalRooms)
                        .keyboardType(.numberPad)
                        .focused($focusedField, equals: .totalRooms)
                        .padding(14)
                        .background(.ultraThinMaterial, in: .rect(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(.white.opacity(0.08), lineWidth: 0.5)
                        )
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Star Rating")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.85))
                    HStack(spacing: 8) {
                        ForEach(1...5, id: \.self) { star in
                            Button {
                                starRating = star
                            } label: {
                                Image(systemName: star <= starRating ? "star.fill" : "star")
                                    .font(.title2)
                                    .foregroundStyle(star <= starRating ? RevOwlTheme.gold : .white.opacity(0.35))
                                    .shadow(color: star <= starRating ? RevOwlTheme.gold.opacity(0.3) : .clear, radius: 4)
                            }
                            .sensoryFeedback(.selection, trigger: starRating)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Property Type")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.85))
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(PropertyType.allCases) { type in
                            Button {
                                propertyType = type
                            } label: {
                                Text(type.rawValue)
                                    .font(.subheadline.weight(.medium))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .glassCardStyle(cornerRadius: 12, elevation: .subtle)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .strokeBorder(propertyType == type ? RevOwlTheme.gold.opacity(0.4) : .clear, lineWidth: 1)
                                    )
                                    .foregroundStyle(propertyType == type ? RevOwlTheme.gold : .white.opacity(0.9))
                            }
                            .sensoryFeedback(.selection, trigger: propertyType)
                        }
                    }
                }

                Button {
                    prefillDemoHotel()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                        Text("Use Demo Hotel (The Coastal Inn)")
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(RevOwlTheme.gold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .glassCardStyle(cornerRadius: 14, elevation: .subtle)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(RevOwlTheme.gold.opacity(0.2), lineWidth: 0.5)
                    )
                }
            }
            .padding(24)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func pickHotel(_ suggestion: HotelSuggestion) {
        didPickHotel = true
        hotelSearchTask?.cancel()
        hotelName = suggestion.name
        if !suggestion.address.isEmpty {
            hotelAddress = suggestion.address
        }
        hotelCoordinate = CLLocationCoordinate2D(latitude: suggestion.latitude, longitude: suggestion.longitude)
        hotelSuggestions = []
        showHotelSuggestions = false
        showAddressSuggestions = false
        addressSuggestions = []
        searchCompleter.search(query: "")
        focusedField = nil
    }

    private func scheduleHotelSearch(query: String) {
        hotelSearchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 3 else {
            hotelSuggestions = []
            showHotelSuggestions = false
            isSearchingHotels = false
            return
        }
        hotelSearchTask = Task {
            try? await Task.sleep(for: .milliseconds(400))
            if Task.isCancelled { return }
            await performHotelSearch(query: trimmed)
        }
    }

    private func performHotelSearch(query: String) async {
        isSearchingHotels = true
        defer { isSearchingHotels = false }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "\(query) hotel"
        request.pointOfInterestFilter = MKPointOfInterestFilter(including: [.hotel])

        do {
            let response = try await MKLocalSearch(request: request).start()
            if Task.isCancelled { return }
            let results: [HotelSuggestion] = response.mapItems.compactMap { item in
                guard let name = item.name else { return nil }
                let coord = item.placemark.coordinate
                let address = [
                    item.placemark.subThoroughfare, item.placemark.thoroughfare,
                    item.placemark.locality, item.placemark.administrativeArea,
                ]
                .compactMap { $0 }
                .joined(separator: ", ")
                return HotelSuggestion(
                    name: name,
                    address: address,
                    latitude: coord.latitude,
                    longitude: coord.longitude
                )
            }
            hotelSuggestions = Array(results.prefix(6))
            showHotelSuggestions = !hotelSuggestions.isEmpty
        } catch {
            if !Task.isCancelled {
                hotelSuggestions = []
                showHotelSuggestions = false
            }
        }
    }

    private func prefillDemoHotel() {
        didPickHotel = true
        hotelSearchTask?.cancel()
        hotelSuggestions = []
        showHotelSuggestions = false
        hotelName = "The Coastal Inn"
        hotelAddress = "123 Ocean Drive, Miami Beach, FL"
        totalRooms = "86"
        starRating = 4
        propertyType = .boutique
        roomTypes = [
            RoomType(id: "rt-1", name: "King", baseRate: 169, floorRate: 129, count: 30),
            RoomType(id: "rt-2", name: "Double Queen", baseRate: 149, floorRate: 109, count: 35),
            RoomType(id: "rt-3", name: "Suite", baseRate: 259, floorRate: 199, count: 12),
            RoomType(id: "rt-4", name: "Standard", baseRate: 119, floorRate: 89, count: 9),
        ]
        discoveredCompetitors = []
        selectedCompetitors = []
        showAddressSuggestions = false
        focusedField = nil
    }

    private var roomTypesStep: some View {
        ScrollView {
            VStack(spacing: 16) {
                ForEach(Array(roomTypes.enumerated()), id: \.element.id) { index, room in
                    VStack(spacing: 12) {
                        HStack {
                            Text(room.name.isEmpty ? "Room Type \(index + 1)" : room.name)
                                .font(.headline)
                                .foregroundStyle(.white)
                            Spacer()
                            if roomTypes.count > 1 {
                                Button {
                                    roomTypes.remove(at: index)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.white.opacity(0.3))
                                }
                            }
                        }

                        VStack(spacing: 10) {
                            roomField("Name", placeholder: "King, Suite, etc.", text: Binding(
                                get: { roomTypes[index].name },
                                set: { roomTypes[index].name = $0 }
                            ), field: .roomName(room.id))
                            roomCurrencyField("Base Rate", value: Binding(
                                get: { roomTypes[index].baseRate },
                                set: { roomTypes[index].baseRate = $0 }
                            ), field: .roomBaseRate(room.id))
                            roomCurrencyField("Floor Rate", value: Binding(
                                get: { roomTypes[index].floorRate },
                                set: { roomTypes[index].floorRate = $0 }
                            ), field: .roomFloorRate(room.id))
                            roomNumberField("Count", value: Binding(
                                get: { roomTypes[index].count },
                                set: { roomTypes[index].count = $0 }
                            ), field: .roomCount(room.id))
                        }
                    }
                    .padding(16)
                    .glassCardStyle(cornerRadius: 16)
                }

                Button {
                    roomTypes.append(RoomType())
                } label: {
                    Label("Add Room Type", systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(RevOwlTheme.gold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .glassCardStyle(cornerRadius: 14, elevation: .subtle)
                }
            }
            .padding(24)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func roomField(_ label: String, placeholder: String, text: Binding<String>, field: SetupField) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
                .frame(width: 80, alignment: .leading)
            TextField(placeholder, text: text)
                .focused($focusedField, equals: field)
                .padding(10)
                .background(.white.opacity(0.04), in: .rect(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.white.opacity(0.06), lineWidth: 0.5))
        }
    }

    private func roomCurrencyField(_ label: String, value: Binding<Double>, field: SetupField) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
                .frame(width: 80, alignment: .leading)
            TextField("$0", value: value, format: .currency(code: "USD"))
                .focused($focusedField, equals: field)
                .padding(10)
                .background(.white.opacity(0.04), in: .rect(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.white.opacity(0.06), lineWidth: 0.5))
                .keyboardType(.decimalPad)
        }
    }

    private func roomNumberField(_ label: String, value: Binding<Int>, field: SetupField) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
                .frame(width: 80, alignment: .leading)
            TextField("0", value: value, format: .number)
                .focused($focusedField, equals: field)
                .padding(10)
                .background(.white.opacity(0.04), in: .rect(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.white.opacity(0.06), lineWidth: 0.5))
                .keyboardType(.numberPad)
        }
    }

    private var competitorStep: some View {
        ScrollView {
            VStack(spacing: 16) {
                if isSearchingCompetitors {
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(RevOwlTheme.gold)
                        Text("Searching for nearby hotels...")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.75))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else if discoveredCompetitors.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "building.2")
                            .font(.system(size: 36))
                            .foregroundStyle(.white.opacity(0.5))
                        Text("No nearby hotels found")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white.opacity(0.8))
                        Text("Enter a valid hotel address in Step 1 to discover competitors.")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                        Button {
                            Task { await searchNearbyCompetitors() }
                        } label: {
                            Label("Search Again", systemImage: "arrow.clockwise")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(RevOwlTheme.gold)
                        }
                        .padding(.top, 8)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else {
                    HStack {
                        Image(systemName: "sparkle.magnifyingglass")
                            .foregroundStyle(RevOwlTheme.gold)
                        Text("\(discoveredCompetitors.count) nearby hotels found")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.8))
                        Spacer()
                        Text("\(selectedCompetitors.count)/\(appState.currentTier.competitorLimit)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(RevOwlTheme.gold)
                    }

                    Text("Your \(appState.currentTier.displayName) plan tracks up to \(appState.currentTier.competitorLimit) competitor\(appState.currentTier.competitorLimit == 1 ? "" : "s"). Upgrade anytime in Settings.")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.6))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    ForEach(discoveredCompetitors) { comp in
                        let isSelected = selectedCompetitors.contains(comp.id)
                        let atLimit = selectedCompetitors.count >= appState.currentTier.competitorLimit
                        Button {
                            if isSelected {
                                selectedCompetitors.remove(comp.id)
                            } else if !atLimit {
                                selectedCompetitors.insert(comp.id)
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(isSelected ? RevOwlTheme.gold : .white.opacity(0.5))
                                    .font(.title3)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(comp.name)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.white)
                                    if let address = comp.address {
                                        Text(address)
                                            .font(.caption)
                                            .foregroundStyle(.white.opacity(0.7))
                                            .lineLimit(1)
                                    }
                                    if comp.distance > 0 {
                                        Text(String(format: "%.1f mi away", comp.distance))
                                            .font(.caption2)
                                            .foregroundStyle(.white.opacity(0.55))
                                    }
                                }

                                Spacer()

                                Image(systemName: "building.2.fill")
                                    .foregroundStyle(.white.opacity(0.4))
                            }
                            .padding(14)
                            .glassCardStyle(cornerRadius: 16, elevation: .subtle)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .strokeBorder(isSelected ? RevOwlTheme.gold.opacity(0.3) : .clear, lineWidth: 1)
                            )
                        }
                        .buttonStyle(GlassPressButtonStyle())
                        .opacity(!isSelected && atLimit ? 0.45 : 1)
                        .sensoryFeedback(.selection, trigger: selectedCompetitors.count)
                    }
                }
            }
            .padding(24)
        }
        .onAppear {
            if discoveredCompetitors.isEmpty && !isSearchingCompetitors {
                Task { await searchNearbyCompetitors() }
            }
        }
    }

    private func searchNearbyCompetitors() async {
        isSearchingCompetitors = true
        discoveredCompetitors = []
        selectedCompetitors = []

        let coordinate: CLLocationCoordinate2D?
        if let existing = hotelCoordinate {
            coordinate = existing
        } else {
            coordinate = await geocodeAddress(hotelAddress)
        }
        hotelCoordinate = coordinate

        guard let coord = coordinate else {
            isSearchingCompetitors = false
            return
        }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "hotel"
        request.region = MKCoordinateRegion(
            center: coord,
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )

        do {
            let search = MKLocalSearch(request: request)
            let response = try await search.start()
            var results: [DiscoveredCompetitor] = []

            for item in response.mapItems {
                guard let name = item.name else { continue }
                let normalizedName = name.lowercased()
                let normalizedHotel = hotelName.lowercased()
                if !normalizedHotel.isEmpty && normalizedName.contains(normalizedHotel) { continue }

                let itemCoord = item.placemark.coordinate
                let dist = distanceMiles(from: coord, to: itemCoord)

                let address = [item.placemark.subThoroughfare, item.placemark.thoroughfare, item.placemark.locality, item.placemark.administrativeArea]
                    .compactMap { $0 }
                    .joined(separator: " ")

                results.append(DiscoveredCompetitor(
                    name: name,
                    latitude: itemCoord.latitude,
                    longitude: itemCoord.longitude,
                    distance: dist,
                    address: address.isEmpty ? nil : address
                ))
            }

            results.sort { $0.distance < $1.distance }
            discoveredCompetitors = Array(results.prefix(10))
        } catch {
            discoveredCompetitors = []
        }

        isSearchingCompetitors = false
    }

    private func geocodeAddress(_ address: String) async -> CLLocationCoordinate2D? {
        guard !address.isEmpty else { return nil }
        let geocoder = CLGeocoder()
        do {
            let placemarks = try await geocoder.geocodeAddressString(address)
            return placemarks.first?.location?.coordinate
        } catch {
            return nil
        }
    }

    private func distanceMiles(from a: CLLocationCoordinate2D, to b: CLLocationCoordinate2D) -> Double {
        let locA = CLLocation(latitude: a.latitude, longitude: a.longitude)
        let locB = CLLocation(latitude: b.latitude, longitude: b.longitude)
        return locA.distance(from: locB) / 1609.34
    }

    private var strategyStep: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Pricing Strategy")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.85))
                    ForEach(PricingStrategy.allCases) { strategy in
                        Button {
                            pricingStrategy = strategy
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: strategy.icon)
                                    .font(.title3)
                                    .foregroundStyle(pricingStrategy == strategy ? RevOwlTheme.gold : .white.opacity(0.55))
                                    .frame(width: 32)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(strategy.rawValue)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.white)
                                    Text(strategy.description)
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.7))
                                }
                                Spacer()
                                Image(systemName: pricingStrategy == strategy ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(pricingStrategy == strategy ? RevOwlTheme.gold : .white.opacity(0.55))
                            }
                            .padding(14)
                            .glassCardStyle(cornerRadius: 14, elevation: .subtle)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .strokeBorder(pricingStrategy == strategy ? RevOwlTheme.gold.opacity(0.25) : .clear, lineWidth: 1)
                            )
                        }
                        .buttonStyle(GlassPressButtonStyle())
                        .sensoryFeedback(.selection, trigger: pricingStrategy)
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Risk Tolerance")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white.opacity(0.85))
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
                    HStack {
                        Text("Conservative")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.6))
                        Spacer()
                        Text("Aggressive")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Max Rate Adjustment")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white.opacity(0.85))
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
                    HStack {
                        Text("±5%")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.6))
                        Spacer()
                        Text("±30%")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
            }
            .padding(24)
        }
    }

    private var notificationPermissionStep: some View {
        VStack(spacing: 32) {
            Spacer()

            ZStack {
                Circle()
                    .fill(RevOwlTheme.gold.opacity(0.06))
                    .frame(width: 180, height: 180)
                Circle()
                    .fill(RevOwlTheme.gold.opacity(0.03))
                    .frame(width: 240, height: 240)
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(RevOwlTheme.gold)
                    .shadow(color: RevOwlTheme.gold.opacity(0.4), radius: 16)
            }

            VStack(spacing: 12) {
                Text("Stay in the Loop")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                Text("Get alerts when competitors change rates, demand spikes, or RevOwl has a pricing recommendation.")
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 16)
            }

            VStack(spacing: 12) {
                Button {
                    requestNotificationPermission()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: notificationPermissionGranted ? "checkmark.circle.fill" : "bell.fill")
                        Text(notificationPermissionGranted ? "Notifications Enabled" : "Allow Notifications")
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        notificationPermissionGranted
                            ? AnyShapeStyle(RevOwlTheme.positive)
                            : AnyShapeStyle(RevOwlTheme.goldGradient),
                        in: .rect(cornerRadius: 14)
                    )
                    .shadow(color: (notificationPermissionGranted ? RevOwlTheme.positive : RevOwlTheme.gold).opacity(0.3), radius: 12, y: 6)
                }
                .disabled(notificationPermissionGranted)
                .sensoryFeedback(.success, trigger: notificationPermissionGranted)

                if !notificationPermissionGranted && !notificationPermissionRequested {
                    Button {
                        withAnimation(.snappy) { currentStep += 1 }
                    } label: {
                        Text("Skip for now")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white.opacity(0.75))
                    }
                }
            }
            .padding(.horizontal, 24)

            Spacer()
        }
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            Task { @MainActor in
                notificationPermissionGranted = granted
                notificationPermissionRequested = true
            }
        }
    }

    private var notificationPreferencesStep: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(spacing: 0) {
                    notificationToggle(icon: "arrow.up.arrow.down.circle.fill", title: "Rate Changes", subtitle: "When competitors adjust their rates", isOn: $enableRateAlerts, color: .cyan)
                    glassDivider
                    notificationToggle(icon: "flame.fill", title: "Demand Surges", subtitle: "When demand score spikes", isOn: $enableDemandAlerts, color: RevOwlTheme.negative)
                    glassDivider
                    notificationToggle(icon: "brain.fill", title: "AI Recommendations", subtitle: "New pricing suggestions", isOn: $enableRecommendationAlerts, color: .purple)
                    glassDivider
                    notificationToggle(icon: "bell.badge.fill", title: "Occupancy Reminders", subtitle: "Daily update prompts", isOn: $enableOccupancyReminders, color: .orange)
                }
                .glassCardStyle(cornerRadius: 16)

                VStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(RevOwlTheme.gold)
                        .shadow(color: RevOwlTheme.gold.opacity(0.4), radius: 12)
                    Text("You're all set!")
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                    Text("RevOwl will start monitoring your market immediately.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 24)
            }
            .padding(24)
        }
    }

    private var glassDivider: some View {
        Rectangle()
            .fill(.white.opacity(0.05))
            .frame(height: 0.5)
            .padding(.leading, 56)
    }

    private func notificationToggle(icon: String, title: String, subtitle: String, isOn: Binding<Bool>, color: Color) -> some View {
        Toggle(isOn: isOn) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
        }
        .tint(RevOwlTheme.gold)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var navigationButtons: some View {
        HStack(spacing: 12) {
            if currentStep > 0 {
                Button {
                    focusedField = nil
                    withAnimation(.snappy) { currentStep -= 1 }
                } label: {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                }
                .buttonStyle(GlassButtonStyle())
            }

            Button {
                focusedField = nil
                if currentStep < totalSteps - 1 {
                    withAnimation(.snappy) { currentStep += 1 }
                } else {
                    finalizeSetup()
                }
            } label: {
                HStack {
                    Text(currentStep == totalSteps - 1 ? "Launch RevOwl" : "Next")
                    Image(systemName: currentStep == totalSteps - 1 ? "checkmark" : "chevron.right")
                }
            }
            .buttonStyle(GoldButtonStyle())
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
        .padding(.top, 8)
    }

    private func finalizeSetup() {
        let computedTotalRooms = Int(totalRooms) ?? roomTypes.reduce(0, { $0 + $1.count })

        let lat = hotelCoordinate?.latitude ?? 0
        let lon = hotelCoordinate?.longitude ?? 0

        let registrationService = HotelRegistrationService.shared
        let name = hotelName.isEmpty ? "My Hotel" : hotelName

        if registrationService.isHotelAlreadyRegistered(name: name, latitude: lat, longitude: lon) {
            showDuplicateHotelAlert = true
            return
        }

        let regId = registrationService.registerHotel(name: name, latitude: lat, longitude: lon)

        let hotel = Hotel(
            name: name,
            address: hotelAddress,
            latitude: lat,
            longitude: lon,
            totalRooms: computedTotalRooms > 0 ? computedTotalRooms : 86,
            roomTypes: roomTypes.filter { !$0.name.isEmpty },
            starRating: starRating,
            propertyType: propertyType,
            ownerId: registrationService.deviceId(),
            tier: .pro,
            pricingStrategy: pricingStrategy,
            riskTolerance: riskTolerance,
            maxRateAdjustment: maxAdjustment,
            registrationId: regId
        )

        let selectedDiscovered = Array(
            discoveredCompetitors
                .filter { selectedCompetitors.contains($0.id) }
                .prefix(appState.currentTier.competitorLimit)
        )
        let newCompetitors = selectedDiscovered.map { disc in
            Competitor(
                name: disc.name,
                latitude: disc.latitude,
                longitude: disc.longitude,
                distance: disc.distance,
                stars: 3,
                otaPresence: ["Booking.com", "Expedia"],
                currentRate: 0,
                availability: "Checking...",
                address: disc.address
            )
        }

        let demandSignals = [
            DemandSignal(source: .seasonality, score: 55, details: "Baseline seasonality for your area."),
            DemandSignal(source: .competitorAvailability, score: 50, details: "Monitoring competitor availability."),
            DemandSignal(source: .weather, score: 40, details: "Weather conditions being tracked."),
        ]

        appState.completeSetup(
            hotel: hotel,
            roomTypes: roomTypes.filter { !$0.name.isEmpty },
            competitors: newCompetitors,
            demandSignals: demandSignals
        )

        onComplete()
    }
}

nonisolated struct HotelSuggestion: Identifiable, Sendable {
    let id: String
    let name: String
    let address: String
    let latitude: Double
    let longitude: Double

    init(name: String, address: String, latitude: Double, longitude: Double) {
        self.id = "\(name)-\(latitude)-\(longitude)"
        self.name = name
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
    }
}

@Observable
class AddressSearchCompleter: NSObject, MKLocalSearchCompleterDelegate {
    var results: [MKLocalSearchCompletion] = []
    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
    }

    func search(query: String) {
        if query.isEmpty {
            results = []
            return
        }
        completer.queryFragment = query
    }

    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        Task { @MainActor in
            self.results = completer.results
        }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in
            self.results = []
        }
    }
}
