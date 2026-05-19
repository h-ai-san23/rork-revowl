import Foundation

nonisolated struct XoteloRateResponse: Codable, Sendable {
    let error: XoteloError?
    let result: XoteloResult?
}

nonisolated struct XoteloError: Codable, Sendable {
    let status_code: Int
    let message: String
}

nonisolated struct XoteloResult: Codable, Sendable {
    let chk_in: String
    let chk_out: String
    let currency: String
    let rates: [XoteloRate]
}

nonisolated struct XoteloRate: Codable, Sendable {
    let code: String
    let name: String
    let rate: Double
    let tax: Double
}

nonisolated struct XoteloListResponse: Codable, Sendable {
    let error: XoteloError?
    let result: XoteloListResult?
}

nonisolated struct XoteloListResult: Codable, Sendable {
    let total_count: Int
    let limit: Int
    let offset: Int
    let list: [XoteloListItem]
}

nonisolated struct XoteloListItem: Codable, Sendable {
    let name: String
    let key: String
    let accommodation_type: String?
    let geo: XoteloGeo?
}

nonisolated struct XoteloGeo: Codable, Sendable {
    let latitude: Double
    let longitude: Double
}

class RateService {
    private static let xoteloBaseURL = "https://data.xotelo.com/api/rates"
    private static let xoteloListURL = "https://data.xotelo.com/api/list"

    // Circuit breaker: Xotelo /api/list endpoint has been observed returning HTTP 400
    // for all requests as of 2026-05. When repeated failures occur, skip the list
    // endpoint entirely and fall back to search-engine resolution for the rest of
    // the session. This avoids wasted requests and slow user-facing operations.
    nonisolated(unsafe) private static var listEndpointFailureCount: Int = 0
    nonisolated(unsafe) private static let listEndpointFailureThreshold: Int = 2
    private static var isListEndpointDisabled: Bool { listEndpointFailureCount >= listEndpointFailureThreshold }

    private static let roomTypeMultipliers: [String: Double] = [
        "Standard": 1.0,
        "King": 1.12,
        "Double Queen": 1.05,
        "Suite": 1.65,
        "Deluxe": 1.25,
        "Premium": 1.35,
    ]

    private static let otaCodeToName: [String: String] = [
        "BookingCom": "Booking.com",
        "Expedia": "Expedia",
        "HotelsCom2": "Hotels.com",
        "Agoda": "Agoda.com",
        "CtripTA": "Trip.com",
        "Priceline": "Priceline",
        "GoogleHPA": "Google Hotels",
        "Vio": "Vio.com",
        "BBHotels": "B&B Hotels",
        "Marriott1": "Marriott",
        "IHG": "IHG",
        "Hilton": "Hilton",
    ]

    private static let otaNameToSource: [String: RateSource] = [
        "Booking.com": .bookingCom,
        "Expedia": .expedia,
        "Hotels.com": .hotelsCom,
        "Agoda.com": .agoda,
        "Trip.com": .tripCom,
        "Priceline": .priceline,
        "Google Hotels": .googleHotels,
    ]

    private static let cityLocationKeys: [String: String] = [
        "los angeles": "g32655",
        "new york": "g60763",
        "san francisco": "g60713",
        "chicago": "g35805",
        "houston": "g56003",
        "phoenix": "g31310",
        "philadelphia": "g60795",
        "san antonio": "g60956",
        "san diego": "g60750",
        "dallas": "g55711",
        "austin": "g30196",
        "jacksonville": "g60805",
        "fort worth": "g55857",
        "columbus": "g50226",
        "charlotte": "g49022",
        "indianapolis": "g37209",
        "san jose": "g33020",
        "seattle": "g60878",
        "denver": "g33388",
        "washington": "g28970",
        "nashville": "g55229",
        "oklahoma city": "g51560",
        "el paso": "g60768",
        "boston": "g60745",
        "portland": "g52024",
        "las vegas": "g45963",
        "memphis": "g55197",
        "louisville": "g39604",
        "baltimore": "g60811",
        "milwaukee": "g60097",
        "albuquerque": "g60933",
        "tucson": "g60950",
        "fresno": "g32373",
        "sacramento": "g32999",
        "mesa": "g31249",
        "kansas city": "g44535",
        "atlanta": "g60898",
        "omaha": "g60885",
        "colorado springs": "g33364",
        "raleigh": "g49463",
        "long beach": "g32648",
        "virginia beach": "g58277",
        "miami": "g34438",
        "miami beach": "g34439",
        "oakland": "g32810",
        "minneapolis": "g43323",
        "tampa": "g34678",
        "new orleans": "g60864",
        "arlington": "g30196",
        "bakersfield": "g32066",
        "honolulu": "g60982",
        "anaheim": "g29092",
        "santa ana": "g33047",
        "riverside": "g32907",
        "st. louis": "g44881",
        "saint louis": "g44881",
        "pittsburgh": "g53449",
        "orlando": "g34515",
        "irvine": "g32555",
        "cincinnati": "g60993",
        "anchorage": "g60880",
        "stockton": "g33102",
        "saint paul": "g43459",
        "newark": "g46671",
        "greensboro": "g49283",
        "buffalo": "g60974",
        "plano": "g56473",
        "lincoln": "g45666",
        "henderson": "g45970",
        "fort lauderdale": "g34227",
        "detroit": "g42139",
        "hollywood": "g34257",
        "beverly hills": "g32070",
        "pasadena": "g32847",
        "glendale": "g32385",
        "santa monica": "g33052",
        "burbank": "g32120",
        "inglewood": "g32525",
        "torrance": "g33150",
        "lawndale": "g32612",
        "hawthorne": "g32449",
        "el segundo": "g32299",
        "redondo beach": "g32954",
        "manhattan beach": "g32688",
        "hermosa beach": "g32464",
        "culver city": "g32226",
        "west hollywood": "g33252",
        "marina del rey": "g32700",
        "downtown los angeles": "g32655",
        "london": "g186338",
        "paris": "g187147",
        "tokyo": "g298184",
        "dubai": "g295424",
        "singapore": "g294265",
        "barcelona": "g187497",
        "rome": "g187791",
        "bangkok": "g293916",
        "sydney": "g255060",
        "hong kong": "g294217",
        "istanbul": "g293974",
        "amsterdam": "g188590",
        "berlin": "g187323",
        "madrid": "g187514",
        "toronto": "g155019",
        "vancouver": "g154943",
        "mexico city": "g150800",
        "cancun": "g150807",
        "mumbai": "g304924",
        "seoul": "g294197",
        "lisbon": "g189158",
        "prague": "g274707",
        "vienna": "g190454",
        "munich": "g187309",
        "milan": "g187849",
        "zurich": "g188113",
    ]

    // MARK: - Primary Resolution: Xotelo List API

    func resolveXoteloKey(hotelName: String, address: String = "", latitude: Double = 0, longitude: Double = 0, engineOffset: Int = 0) async -> String {
        let cleanName = hotelName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return "" }

        if let key = await resolveViaXoteloList(hotelName: cleanName, address: address, latitude: latitude, longitude: longitude) {
            return key
        }

        if let key = await resolveViaSearchEngines(hotelName: cleanName, address: address, engineOffset: engineOffset) {
            return key
        }

        return ""
    }

    private func resolveViaXoteloList(hotelName: String, address: String, latitude: Double, longitude: Double) async -> String? {
        if Self.isListEndpointDisabled { return nil }
        let locationKeys = findLocationKeys(address: address, latitude: latitude, longitude: longitude)
        guard !locationKeys.isEmpty else { return nil }

        for locationKey in locationKeys {
            if let key = await searchXoteloList(locationKey: locationKey, hotelName: hotelName, latitude: latitude, longitude: longitude) {
                return key
            }
            try? await Task.sleep(for: .seconds(0.5))
        }

        return nil
    }

    private func findLocationKeys(address: String, latitude: Double, longitude: Double) -> [String] {
        var keys: [String] = []
        let addressLower = address.lowercased()

        let cityComponents = extractCityNames(from: addressLower)

        for city in cityComponents {
            if let key = Self.cityLocationKeys[city] {
                if !keys.contains(key) {
                    keys.append(key)
                }
            }
        }

        if keys.isEmpty {
            for (city, key) in Self.cityLocationKeys {
                if addressLower.contains(city) && !keys.contains(key) {
                    keys.append(key)
                }
            }
        }

        if keys.isEmpty && (latitude != 0 || longitude != 0) {
            let nearbyKeys = findNearestCityKeys(latitude: latitude, longitude: longitude)
            keys.append(contentsOf: nearbyKeys)
        }

        return Array(keys.prefix(3))
    }

    private func extractCityNames(from address: String) -> [String] {
        var cities: [String] = []

        let parts = address.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }

        for part in parts {
            let cleaned = part.replacingOccurrences(of: "\\b(ca|ny|tx|fl|il|pa|oh|ga|nc|mi|nj|va|wa|az|ma|tn|in|mo|md|wi|co|mn|sc|al|la|ky|or|ok|ct|ut|ia|nv|ar|ms|ks|nm|ne|id|wv|hi|nh|me|mt|ri|de|sd|nd|ak|vt|wy|dc|usa|united states)\\b", with: "", options: .regularExpression)
                .replacingOccurrences(of: "\\d{5}(-\\d{4})?", with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if !cleaned.isEmpty && cleaned.count > 2 {
                cities.append(cleaned)
            }
        }

        return cities
    }

    private static let cityCoordinates: [(city: String, key: String, lat: Double, lon: Double)] = [
        ("los angeles", "g32655", 34.0522, -118.2437),
        ("new york", "g60763", 40.7128, -74.0060),
        ("san francisco", "g60713", 37.7749, -122.4194),
        ("chicago", "g35805", 41.8781, -87.6298),
        ("houston", "g56003", 29.7604, -95.3698),
        ("miami", "g34438", 25.7617, -80.1918),
        ("miami beach", "g34439", 25.7907, -80.1300),
        ("las vegas", "g45963", 36.1699, -115.1398),
        ("seattle", "g60878", 47.6062, -122.3321),
        ("denver", "g33388", 39.7392, -104.9903),
        ("boston", "g60745", 42.3601, -71.0589),
        ("atlanta", "g60898", 33.7490, -84.3880),
        ("dallas", "g55711", 32.7767, -96.7970),
        ("washington", "g28970", 38.9072, -77.0369),
        ("phoenix", "g31310", 33.4484, -112.0740),
        ("san diego", "g60750", 32.7157, -117.1611),
        ("orlando", "g34515", 28.5383, -81.3792),
        ("nashville", "g55229", 36.1627, -86.7816),
        ("portland", "g52024", 45.5152, -122.6784),
        ("new orleans", "g60864", 29.9511, -90.0715),
        ("tampa", "g34678", 27.9506, -82.4572),
        ("austin", "g30196", 30.2672, -97.7431),
        ("fort lauderdale", "g34227", 26.1224, -80.1373),
        ("lawndale", "g32612", 33.8872, -118.3526),
        ("inglewood", "g32525", 33.9617, -118.3531),
        ("beverly hills", "g32070", 34.0736, -118.4004),
        ("santa monica", "g33052", 34.0195, -118.4912),
        ("hollywood", "g34257", 34.0928, -118.3287),
        ("long beach", "g32648", 33.7701, -118.1937),
        ("anaheim", "g29092", 33.8366, -117.9143),
        ("pasadena", "g32847", 34.1478, -118.1445),
        ("honolulu", "g60982", 21.3069, -157.8583),
        ("london", "g186338", 51.5074, -0.1278),
        ("paris", "g187147", 48.8566, 2.3522),
        ("tokyo", "g298184", 35.6762, 139.6503),
        ("dubai", "g295424", 25.2048, 55.2708),
        ("singapore", "g294265", 1.3521, 103.8198),
        ("barcelona", "g187497", 41.3874, 2.1686),
        ("rome", "g187791", 41.9028, 12.4964),
        ("bangkok", "g293916", 13.7563, 100.5018),
        ("sydney", "g255060", -33.8688, 151.2093),
        ("toronto", "g155019", 43.6532, -79.3832),
        ("amsterdam", "g188590", 52.3676, 4.9041),
    ]

    private func findNearestCityKeys(latitude: Double, longitude: Double) -> [String] {
        let sorted = Self.cityCoordinates.sorted { a, b in
            let distA = haversineDistance(lat1: latitude, lon1: longitude, lat2: a.lat, lon2: a.lon)
            let distB = haversineDistance(lat1: latitude, lon1: longitude, lat2: b.lat, lon2: b.lon)
            return distA < distB
        }
        return Array(sorted.prefix(2).map(\.key))
    }

    private func haversineDistance(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let R = 6371.0
        let dLat = (lat2 - lat1) * .pi / 180
        let dLon = (lon2 - lon1) * .pi / 180
        let a = sin(dLat / 2) * sin(dLat / 2) +
            cos(lat1 * .pi / 180) * cos(lat2 * .pi / 180) *
            sin(dLon / 2) * sin(dLon / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return R * c
    }

    private func searchXoteloList(locationKey: String, hotelName: String, latitude: Double, longitude: Double) async -> String? {
        let maxPages = 5
        let normalizedTarget = normalizeHotelName(hotelName)

        for page in 0..<maxPages {
            let offset = page * 30
            let urlString = "\(Self.xoteloListURL)?location_key=\(locationKey)&offset=\(offset)"
            guard let url = URL(string: urlString) else { return nil }

            var request = URLRequest(url: url)
            request.timeoutInterval = 20

            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { return nil }

                let decoded = try JSONDecoder().decode(XoteloListResponse.self, from: data)
                if decoded.error != nil && decoded.result == nil {
                    Self.listEndpointFailureCount += 1
                    return nil
                }
                guard let result = decoded.result else { return nil }

                var bestMatch: (key: String, score: Double) = ("", 0)

                for item in result.list {
                    let normalizedItem = normalizeHotelName(item.name)
                    let nameScore = nameSimilarityScore(normalizedTarget, normalizedItem)

                    var geoBonus: Double = 0
                    if let geo = item.geo, latitude != 0, longitude != 0 {
                        let dist = haversineDistance(lat1: latitude, lon1: longitude, lat2: geo.latitude, lon2: geo.longitude)
                        if dist < 0.5 { geoBonus = 0.3 }
                        else if dist < 1.0 { geoBonus = 0.15 }
                        else if dist < 2.0 { geoBonus = 0.05 }
                    }

                    let totalScore = nameScore + geoBonus

                    if totalScore > bestMatch.score {
                        bestMatch = (item.key, totalScore)
                    }

                    if nameScore > 0.85 {
                        return item.key
                    }
                }

                if bestMatch.score > 0.6 {
                    return bestMatch.key
                }

                if result.list.count < 30 || offset + 30 >= result.total_count {
                    break
                }
            } catch {
                break
            }

            try? await Task.sleep(for: .seconds(0.3))
        }

        return nil
    }

    private func normalizeHotelName(_ name: String) -> String {
        name.lowercased()
            .replacingOccurrences(of: "hotel", with: "")
            .replacingOccurrences(of: "resort", with: "")
            .replacingOccurrences(of: "suites", with: "")
            .replacingOccurrences(of: "suite", with: "")
            .replacingOccurrences(of: "inn", with: "")
            .replacingOccurrences(of: "by ihg", with: "")
            .replacingOccurrences(of: "by marriott", with: "")
            .replacingOccurrences(of: "by hilton", with: "")
            .replacingOccurrences(of: "by wyndham", with: "")
            .replacingOccurrences(of: "&", with: "and")
            .replacingOccurrences(of: "the ", with: "")
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func nameSimilarityScore(_ a: String, _ b: String) -> Double {
        if a == b { return 1.0 }
        if a.contains(b) || b.contains(a) { return 0.9 }

        let wordsA = Set(a.components(separatedBy: .whitespaces).filter { $0.count > 1 })
        let wordsB = Set(b.components(separatedBy: .whitespaces).filter { $0.count > 1 })
        guard !wordsA.isEmpty, !wordsB.isEmpty else { return 0 }

        let intersection = wordsA.intersection(wordsB)
        let union = wordsA.union(wordsB)
        let jaccard = Double(intersection.count) / Double(union.count)

        let significantWords = Set(["best", "western", "plus", "hilton", "marriott", "courtyard", "holiday", "express", "hyatt", "regency", "westin", "sheraton", "doubletree", "hampton", "comfort", "quality", "fairfield", "residence", "springhill", "crowne", "plaza", "radisson", "wyndham", "ramada", "la", "quinta", "motel", "days", "super", "econo", "lodge", "embassy", "homewood"])
        let sigA = wordsA.intersection(significantWords)
        let sigB = wordsB.intersection(significantWords)
        let sigMatch = !sigA.isEmpty && sigA == sigB ? 0.2 : 0.0

        return min(1.0, jaccard + sigMatch)
    }

    // MARK: - Fallback: Search Engine Resolution

    private func resolveViaSearchEngines(hotelName: String, address: String, engineOffset: Int) async -> String? {
        let primaryQuery: String
        let fallbackQuery: String
        if address.isEmpty {
            primaryQuery = "tripadvisor \(hotelName) hotel"
            fallbackQuery = "site:tripadvisor.com \(hotelName) hotel"
        } else {
            primaryQuery = "tripadvisor \(hotelName) \(address)"
            fallbackQuery = "site:tripadvisor.com \(hotelName) hotel"
        }

        let engines: [(String) async -> String?] = [
            { q in await self.resolveViaDuckDuckGo(query: q) },
            { q in await self.resolveViaBraveSearch(query: q) },
            { q in await self.resolveViaBingSearch(query: q) },
            { q in await self.resolveViaGoogleSearch(query: q) },
        ]

        let queries = [primaryQuery, fallbackQuery]
        for query in queries {
            for i in 0..<engines.count {
                let idx = (i + engineOffset) % engines.count
                if let key = await engines[idx](query) {
                    return key
                }
            }
        }

        return nil
    }

    private func extractTripAdvisorKey(from html: String) -> String? {
        let patterns = [
            #"Hotel_Review-(g\d+-d\d+)"#,
            #"hotel_key=(g\d+-d\d+)"#,
            #"/Hotel_Review-(g\d+-d\d+)"#,
            #"ShowUrl.*?(g\d+-d\d+)"#,
            #"locationId.*?(g\d+-d\d+)"#,
        ]
        var candidates: [String: Int] = [:]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let matches = regex.matches(in: html, range: NSRange(html.startIndex..., in: html))
            for match in matches {
                guard let range = Range(match.range(at: 1), in: html) else { continue }
                let key = String(html[range])
                candidates[key, default: 0] += 1
            }
        }
        return candidates.max(by: { $0.value < $1.value })?.key
    }

    private func resolveViaBraveSearch(query: String) async -> String? {
        let sanitized = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let urlString = "https://search.brave.com/search?q=\(sanitized)&source=web"
        guard let url = URL(string: urlString) else { return nil }
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
        request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        request.timeoutInterval = 15
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { return nil }
            guard let html = String(data: data, encoding: .utf8) else { return nil }
            return extractTripAdvisorKey(from: html)
        } catch {
            return nil
        }
    }

    private func resolveViaDuckDuckGo(query: String) async -> String? {
        let sanitized = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let urlString = "https://html.duckduckgo.com/html/?q=\(sanitized)"
        guard let url = URL(string: urlString) else { return nil }
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15", forHTTPHeaderField: "User-Agent")
        request.setValue("text/html", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { return nil }
            guard let html = String(data: data, encoding: .utf8) else { return nil }
            return extractTripAdvisorKey(from: html)
        } catch {
            return nil
        }
    }

    private func resolveViaGoogleSearch(query: String) async -> String? {
        let sanitized = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let urlString = "https://www.google.com/search?q=\(sanitized)"
        guard let url = URL(string: urlString) else { return nil }
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let html = String(data: data, encoding: .utf8) else { return nil }
            return extractTripAdvisorKey(from: html)
        } catch {
            return nil
        }
    }

    private func resolveViaBingSearch(query: String) async -> String? {
        let sanitized = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let urlString = "https://www.bing.com/search?q=\(sanitized)"
        guard let url = URL(string: urlString) else { return nil }
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
        request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        request.timeoutInterval = 15
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { return nil }
            guard let html = String(data: data, encoding: .utf8) else { return nil }
            return extractTripAdvisorKey(from: html)
        } catch {
            return nil
        }
    }

    // MARK: - Key Resolution for Multiple Items

    func resolveXoteloKeys(for competitors: [Competitor]) async -> [Competitor] {
        var updated = competitors
        let unresolvedIndices = competitors.enumerated().compactMap { $0.element.xoteloKey.isEmpty ? $0.offset : nil }

        guard !unresolvedIndices.isEmpty else { return updated }

        var locationHotels: [XoteloListItem] = []
        if !Self.isListEndpointDisabled {
            let firstCompetitor = competitors[unresolvedIndices[0]]
            let locationKeys = findLocationKeys(
                address: firstCompetitor.address ?? "",
                latitude: firstCompetitor.latitude,
                longitude: firstCompetitor.longitude
            )

            for locationKey in locationKeys {
                let hotels = await fetchAllXoteloListItems(locationKey: locationKey, maxPages: 8)
                locationHotels.append(contentsOf: hotels)
                if !hotels.isEmpty { break }
            }
        }

        for index in unresolvedIndices {
            let competitor = updated[index]
            let normalizedTarget = normalizeHotelName(competitor.name)

            var bestMatch: (key: String, score: Double) = ("", 0)

            for item in locationHotels {
                let normalizedItem = normalizeHotelName(item.name)
                let nameScore = nameSimilarityScore(normalizedTarget, normalizedItem)

                var geoBonus: Double = 0
                if let geo = item.geo, competitor.latitude != 0, competitor.longitude != 0 {
                    let dist = haversineDistance(lat1: competitor.latitude, lon1: competitor.longitude, lat2: geo.latitude, lon2: geo.longitude)
                    if dist < 0.3 { geoBonus = 0.3 }
                    else if dist < 1.0 { geoBonus = 0.15 }
                    else if dist < 2.0 { geoBonus = 0.05 }
                }

                let totalScore = nameScore + geoBonus

                if totalScore > bestMatch.score {
                    bestMatch = (item.key, totalScore)
                }
            }

            if bestMatch.score > 0.5 {
                updated[index].xoteloKey = bestMatch.key
            }
        }

        let stillUnresolved = updated.enumerated().compactMap { $0.element.xoteloKey.isEmpty ? $0.offset : nil }
        for (engineOffset, index) in stillUnresolved.enumerated() {
            let competitor = updated[index]
            let key = await resolveXoteloKey(
                hotelName: competitor.name,
                address: competitor.address ?? "",
                latitude: competitor.latitude,
                longitude: competitor.longitude,
                engineOffset: engineOffset
            )
            if !key.isEmpty {
                updated[index].xoteloKey = key
            }
            if engineOffset < stillUnresolved.count - 1 {
                try? await Task.sleep(for: .seconds(1))
            }
        }

        return updated
    }

    private func fetchAllXoteloListItems(locationKey: String, maxPages: Int) async -> [XoteloListItem] {
        var allItems: [XoteloListItem] = []

        for page in 0..<maxPages {
            let offset = page * 30
            let urlString = "\(Self.xoteloListURL)?location_key=\(locationKey)&offset=\(offset)"
            guard let url = URL(string: urlString) else { break }

            var request = URLRequest(url: url)
            request.timeoutInterval = 20

            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { break }
                let decoded = try JSONDecoder().decode(XoteloListResponse.self, from: data)
                if decoded.error != nil && decoded.result == nil {
                    Self.listEndpointFailureCount += 1
                    break
                }
                guard let result = decoded.result else { break }
                allItems.append(contentsOf: result.list)
                if allItems.count >= result.total_count || result.list.count < 30 {
                    break
                }
            } catch {
                break
            }

            try? await Task.sleep(for: .seconds(0.3))
        }

        return allItems
    }

    func resolveHotelXoteloKey(hotel: Hotel) async -> String {
        if !hotel.xoteloKey.isEmpty { return hotel.xoteloKey }
        return await resolveXoteloKey(
            hotelName: hotel.name,
            address: hotel.address,
            latitude: hotel.latitude,
            longitude: hotel.longitude
        )
    }

    // MARK: - Rate Fetching

    func fetchXoteloRates(hotelKey: String, checkIn: Date? = nil, checkOut: Date? = nil) async -> [XoteloRate] {
        guard !hotelKey.isEmpty else { return [] }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        // Broader fallback range: hotels may not have rates loaded for some dates.
        // We try a spread of upcoming dates to maximize the chance of returning data.
        let dateOffsets = [3, 7, 14, 21, 30, 45, 60]
        let calendar = Calendar.current

        if let checkIn = checkIn {
            let outDate = checkOut ?? calendar.date(byAdding: .day, value: 1, to: checkIn) ?? checkIn
            return await fetchRatesForDate(hotelKey: hotelKey, checkIn: formatter.string(from: checkIn), checkOut: formatter.string(from: outDate))
        }

        for offset in dateOffsets {
            let inDate = calendar.date(byAdding: .day, value: offset, to: .now) ?? .now
            let outDate = calendar.date(byAdding: .day, value: 1, to: inDate) ?? inDate
            let rates = await fetchRatesForDate(hotelKey: hotelKey, checkIn: formatter.string(from: inDate), checkOut: formatter.string(from: outDate))
            if !rates.isEmpty { return rates }
        }
        return []
    }

    private func fetchRatesForDate(hotelKey: String, checkIn: String, checkOut: String) async -> [XoteloRate] {
        let urlString = "\(Self.xoteloBaseURL)?hotel_key=\(hotelKey)&chk_in=\(checkIn)&chk_out=\(checkOut)"
        guard let url = URL(string: urlString) else { return [] }

        var request = URLRequest(url: url)
        request.timeoutInterval = 30

        for attempt in 0..<3 {
            do {
                if attempt > 0 {
                    try await Task.sleep(for: .seconds(Double(attempt) * 2.0))
                }
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { continue }
                let decoded = try JSONDecoder().decode(XoteloRateResponse.self, from: data)
                if let rates = decoded.result?.rates, !rates.isEmpty {
                    return rates
                }
            } catch {
                continue
            }
        }
        return []
    }

    // MARK: - Competitor Rate Fetching

    func fetchCompetitorRates(competitors: [Competitor]) async -> [Competitor] {
        var updated = competitors

        let batchSize = 3
        let indices = Array(competitors.indices)
        for batchStart in stride(from: 0, to: indices.count, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, indices.count)
            let batch = Array(indices[batchStart..<batchEnd])

            await withTaskGroup(of: (Int, [XoteloRate]).self) { group in
                for index in batch {
                    let competitor = competitors[index]
                    group.addTask {
                        let rates = await self.fetchXoteloRates(hotelKey: competitor.xoteloKey)
                        return (index, rates)
                    }
                }
                for await (index, xoteloRates) in group {
                    if !xoteloRates.isEmpty {
                        let oldRate = updated[index].currentRate
                        var otaRates: [OTARateInfo] = []

                        for xRate in xoteloRates {
                            let displayName = Self.otaCodeToName[xRate.code] ?? xRate.name
                            otaRates.append(OTARateInfo(
                                otaName: displayName,
                                rate: xRate.rate,
                                tax: xRate.tax,
                                roomType: "Standard"
                            ))
                        }

                        updated[index].otaRates = otaRates
                        updated[index].otaPresence = otaRates.map(\.otaName)

                        if let bookingRate = otaRates.first(where: { $0.otaName == "Booking.com" }) {
                            updated[index].currentRate = bookingRate.rate
                        } else if let first = otaRates.first {
                            updated[index].currentRate = first.rate
                        }

                        let newRate = updated[index].currentRate
                        if oldRate > 0 {
                            updated[index].rateChange = ((newRate - oldRate) / oldRate) * 100
                        }
                        updated[index].lastRateUpdate = .now
                        updated[index].availability = "Available"
                    } else if !updated[index].xoteloKey.isEmpty {
                        updated[index].availability = "No Rates Today"
                    } else {
                        updated[index].availability = "Key Not Found"
                    }
                }
            }

            if batchEnd < indices.count {
                try? await Task.sleep(for: .seconds(1))
            }
        }

        return updated
    }

    // MARK: - Hotel OTA Rate Fetching

    func fetchHotelOTARates(hotel: Hotel) async -> [HotelRateEntry] {
        let xoteloRates = await fetchXoteloRates(hotelKey: hotel.xoteloKey)

        if xoteloRates.isEmpty {
            return hotel.roomTypes.map { roomType in
                HotelRateEntry(
                    roomTypeId: roomType.id, roomTypeName: roomType.name,
                    currentRate: roomType.baseRate, source: .manual,
                    otaRates: []
                )
            }
        }

        let baseOTARates = xoteloRates.compactMap { xRate -> (String, Double, Double)? in
            let displayName = Self.otaCodeToName[xRate.code] ?? xRate.name
            return (displayName, xRate.rate, xRate.tax)
        }

        return hotel.roomTypes.map { roomType in
            let multiplier = Self.roomTypeMultipliers[roomType.name] ?? 1.0
            let standardMultiplier = Self.roomTypeMultipliers["Standard"] ?? 1.0
            let ratio = multiplier / standardMultiplier

            var otaRates: [OTARateInfo] = []
            for (otaName, baseRate, tax) in baseOTARates {
                let adjustedRate = (baseRate * ratio).rounded()
                let adjustedTax = (tax * ratio).rounded()
                otaRates.append(OTARateInfo(
                    otaName: otaName,
                    rate: max(roomType.floorRate, adjustedRate),
                    tax: adjustedTax,
                    roomType: roomType.name
                ))
            }

            let primaryRate: Double
            let primarySource: RateSource
            if let booking = otaRates.first(where: { $0.otaName == "Booking.com" }) {
                primaryRate = booking.rate
                primarySource = .bookingCom
            } else if let first = otaRates.first {
                primaryRate = first.rate
                primarySource = Self.otaNameToSource[first.otaName] ?? .manual
            } else {
                primaryRate = roomType.baseRate
                primarySource = .manual
            }

            return HotelRateEntry(
                roomTypeId: roomType.id, roomTypeName: roomType.name,
                currentRate: primaryRate, source: primarySource,
                otaRates: otaRates
            )
        }
    }

    // MARK: - Dynamic Recommendations

    func generateDynamicRecommendations(
        hotelRates: [HotelRateEntry],
        competitors: [Competitor],
        occupancy: [OccupancyEntry],
        demandScore: Int,
        strategy: PricingStrategy,
        riskTolerance: Double,
        maxAdjustment: Double,
        roomTypes: [RoomType]
    ) -> [Recommendation] {
        var recommendations: [Recommendation] = []

        let activeCompetitors = competitors.filter { $0.currentRate > 0 }
        let competitorAvg = activeCompetitors.isEmpty ? 0 : activeCompetitors.map(\.currentRate).reduce(0, +) / Double(activeCompetitors.count)
        let competitorMin = activeCompetitors.map(\.currentRate).min() ?? 0
        let competitorMax = activeCompetitors.map(\.currentRate).max() ?? 0
        let soldOutCount = competitors.filter { $0.availability == "Sold Out" }.count

        for entry in hotelRates {
            guard let roomType = roomTypes.first(where: { $0.id == entry.roomTypeId }) else { continue }
            let occupancyEntry = occupancy.first(where: { $0.roomTypeId == entry.roomTypeId })
            let occupancyRate = occupancyEntry.map { Double($0.roomsSold) / Double(max($0.totalRooms, 1)) } ?? 0.5

            guard competitorAvg > 0 || demandScore > 0 else { continue }

            let effectiveCompAvg = competitorAvg > 0 ? competitorAvg : entry.currentRate

            let demandMultiplier: Double = {
                if demandScore > 70 { return 1.0 + (Double(demandScore - 70) / 100.0) * riskTolerance }
                if demandScore < 40 { return 1.0 - (Double(40 - demandScore) / 100.0) * riskTolerance * 0.5 }
                return 1.0
            }()

            let competitorPressure = entry.currentRate > 0 ? (effectiveCompAvg - entry.currentRate) / entry.currentRate : 0

            let occupancyFactor: Double = {
                switch strategy {
                case .occupancyFocused:
                    if occupancyRate < 0.5 { return -0.05 * riskTolerance }
                    if occupancyRate > 0.85 { return 0.08 * riskTolerance }
                    return 0
                case .adrFocused:
                    if occupancyRate > 0.6 { return 0.06 * riskTolerance }
                    return -0.02
                case .balanced:
                    if occupancyRate < 0.5 { return -0.03 * riskTolerance }
                    if occupancyRate > 0.8 { return 0.05 * riskTolerance }
                    return 0
                }
            }()

            let soldOutBonus = soldOutCount > 0 ? Double(soldOutCount) * 0.02 * riskTolerance : 0

            let rawAdjustment = (competitorPressure * 0.4 + occupancyFactor + (demandMultiplier - 1.0) * 0.6 + soldOutBonus)
            let clampedAdjustment = max(-maxAdjustment, min(maxAdjustment, rawAdjustment))
            let recommendedRate = max(roomType.floorRate, (entry.currentRate * (1.0 + clampedAdjustment)).rounded())

            let percentChange = entry.currentRate > 0 ? ((recommendedRate - entry.currentRate) / entry.currentRate) * 100 : 0
            guard abs(percentChange) > 1.0 else { continue }

            let confidence: ConfidenceLevel = {
                let hasRealCompData = !activeCompetitors.isEmpty
                let hasStrongSignal = demandScore > 70 || demandScore < 30
                if hasRealCompData && hasStrongSignal { return .high }
                if hasRealCompData || hasStrongSignal { return .medium }
                return .low
            }()

            var reasons: [String] = []
            if !activeCompetitors.isEmpty {
                reasons.append("Competitor avg \(competitorAvg.formatted(.currency(code: "USD").precision(.fractionLength(0)))) (range \(competitorMin.formatted(.currency(code: "USD").precision(.fractionLength(0))))-\(competitorMax.formatted(.currency(code: "USD").precision(.fractionLength(0)))))")
            }
            if demandScore > 70 { reasons.append("High demand score (\(demandScore))") }
            if demandScore < 40 { reasons.append("Low demand (\(demandScore))") }
            if occupancyRate > 0.8 { reasons.append("High occupancy (\(Int(occupancyRate * 100))%)") }
            if occupancyRate < 0.5 { reasons.append("Low occupancy (\(Int(occupancyRate * 100))%)") }
            if soldOutCount > 0 { reasons.append("\(soldOutCount) competitor(s) sold out") }

            let reasoning = reasons.isEmpty ? "Market conditions suggest rate adjustment." : reasons.joined(separator: ". ") + "."

            let expectedOccImpact = percentChange > 0 ? -abs(percentChange) * 0.3 : abs(percentChange) * 0.5

            recommendations.append(Recommendation(
                roomTypeId: entry.roomTypeId, roomTypeName: entry.roomTypeName,
                currentRate: entry.currentRate, recommendedRate: recommendedRate,
                confidence: confidence, reasoning: reasoning, status: .pending,
                expectedADRImpact: recommendedRate - entry.currentRate,
                expectedOccupancyImpact: expectedOccImpact,
                dateRange: "Dynamic Rate", createdAt: .now
            ))
        }
        return recommendations
    }
}
