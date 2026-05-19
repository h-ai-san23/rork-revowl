import Foundation

nonisolated enum LocalEventsError: Error, Sendable {
    case missingConfig
    case authError
    case insufficientBalance
    case rateLimited
    case serverError(Int)
    case parseFailure
}

nonisolated struct LocalEventsService: Sendable {
    private nonisolated struct ChatResponse: Codable {
        struct Choice: Codable {
            struct Message: Codable { let content: String? }
            let message: Message
        }
        let choices: [Choice]
    }

    private nonisolated struct EventDTO: Codable {
        let title: String
        let venue: String
        let date: String
        let category: String
        let expected_attendance: Int?
        let impact: String?
        let distance_miles: Double?
        let source_url: String?
    }

    private nonisolated struct EventsPayload: Codable {
        let events: [EventDTO]
    }

    func fetchUpcomingEvents(
        city: String,
        latitude: Double,
        longitude: Double,
        radiusMiles: Int = 25,
        daysAhead: Int = 60
    ) async throws -> [LocalEvent] {
        let toolkitURL = Config.EXPO_PUBLIC_TOOLKIT_URL
        let secret = Config.EXPO_PUBLIC_RORK_TOOLKIT_SECRET_KEY
        guard !toolkitURL.isEmpty, !secret.isEmpty else {
            throw LocalEventsError.missingConfig
        }

        guard let url = URL(string: "\(toolkitURL)/v2/vercel/v1/chat/completions") else {
            throw LocalEventsError.missingConfig
        }

        let locationDescriptor: String = {
            if !city.isEmpty { return city }
            return "lat \(latitude), lon \(longitude)"
        }()

        let systemPrompt = """
        You are a hospitality demand researcher. Search the live web (Google, official venue \
        sites, ticketing sites, local news) for upcoming events that drive hotel demand near a \
        specific location.

        Return ONLY a single valid JSON object — no markdown, no commentary, no code fences.

        Schema:
        {
          "events": [
            {
              "title": string,
              "venue": string,
              "date": string (ISO-8601 yyyy-MM-dd or yyyy-MM-ddTHH:mm),
              "category": "Sports" | "Concert" | "Festival" | "Conference" | "Performing Arts" | "Community" | "Other",
              "expected_attendance": integer,
              "impact": "High" | "Medium" | "Low",
              "distance_miles": number,
              "source_url": string (full https:// URL of the listing)
            }
          ]
        }

        Rules:
        - Only include events in the next \(daysAhead) days within ~\(radiusMiles) miles.
        - Prioritize high-demand drivers: pro/college sports, major concerts/tours, festivals, \
          conventions, citywide conferences, marathons, holiday parades.
        - Skip routine recurring events that don't move hotel demand.
        - Estimate attendance from venue capacity if not published.
        - impact = "High" if expected_attendance >= 15000 OR sold-out major venue; \
          "Medium" if 3000-15000; "Low" otherwise.
        - source_url MUST be a real URL you found (Ticketmaster, venue, team site, news article).
        - If you can't find any qualifying events, return {"events": []}.
        - Maximum 12 events, sorted by date ascending.
        """

        let userPrompt = """
        Find upcoming high-demand events near \(locationDescriptor) (within \(radiusMiles) miles) \
        in the next \(daysAhead) days. Today is \(Self.todayString()).
        """

        let body: [String: Any] = [
            "model": "perplexity/sonar-pro",
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userPrompt]
            ],
            "search_recency_filter": "month"
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(secret)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw LocalEventsError.serverError(-1)
        }
        switch http.statusCode {
        case 200: break
        case 401: throw LocalEventsError.authError
        case 402: throw LocalEventsError.insufficientBalance
        case 429: throw LocalEventsError.rateLimited
        default:  throw LocalEventsError.serverError(http.statusCode)
        }

        let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
        guard let content = decoded.choices.first?.message.content else {
            throw LocalEventsError.parseFailure
        }
        let payload = try Self.extractEventsPayload(from: content)
        return payload.events.compactMap { Self.toLocalEvent($0) }
    }

    private static func extractEventsPayload(from text: String) throws -> EventsPayload {
        let cleaned = stripCodeFences(text)
        if let data = cleaned.data(using: .utf8),
           let payload = try? JSONDecoder().decode(EventsPayload.self, from: data) {
            return payload
        }
        if let range = cleaned.range(of: "{", options: .literal),
           let endRange = cleaned.range(of: "}", options: .backwards) {
            let snippet = String(cleaned[range.lowerBound...endRange.lowerBound])
            if let data = snippet.data(using: .utf8),
               let payload = try? JSONDecoder().decode(EventsPayload.self, from: data) {
                return payload
            }
        }
        throw LocalEventsError.parseFailure
    }

    private static func stripCodeFences(_ s: String) -> String {
        var t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.hasPrefix("```") {
            if let firstNewline = t.firstIndex(of: "\n") {
                t = String(t[t.index(after: firstNewline)...])
            }
            if t.hasSuffix("```") {
                t = String(t.dropLast(3))
            }
        }
        return t.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func toLocalEvent(_ dto: EventDTO) -> LocalEvent? {
        guard let date = parseDate(dto.date) else { return nil }
        let category = EventCategory(rawValue: dto.category) ?? .other
        let impact: EventImpact = {
            switch dto.impact?.lowercased() {
            case "high": return .high
            case "low":  return .low
            default:     return .medium
            }
        }()
        return LocalEvent(
            title: dto.title,
            venue: dto.venue,
            date: date,
            category: category,
            expectedAttendance: dto.expected_attendance ?? 0,
            impact: impact,
            distanceMiles: dto.distance_miles ?? 0,
            sourceURL: dto.source_url ?? ""
        )
    }

    private static func parseDate(_ s: String) -> Date? {
        let isoFull = ISO8601DateFormatter()
        if let d = isoFull.date(from: s) { return d }

        let formats = [
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd'T'HH:mm",
            "yyyy-MM-dd HH:mm",
            "yyyy-MM-dd"
        ]
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        for fmt in formats {
            f.dateFormat = fmt
            if let d = f.date(from: s) { return d }
        }
        return nil
    }

    private static func todayString() -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: .now)
    }
}
