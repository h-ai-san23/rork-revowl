import Foundation

/// User-facing API error. `code` mirrors the backend's stable error codes.
nonisolated struct APIError: Error, LocalizedError, Sendable {
    let status: Int
    let code: String
    let message: String

    var errorDescription: String? { message }
    var isUnauthenticated: Bool { status == 401 }
    var isPlanLimit: Bool { status == 402 }

    static let offline = APIError(status: 0, code: "offline", message: "You appear to be offline. Check your connection and try again.")
    static let decoding = APIError(status: 0, code: "decoding", message: "We received an unexpected response. Please try again.")
}

extension Error {
    /// Friendly, sanitized message for display.
    nonisolated var userMessage: String {
        if let api = self as? APIError { return api.message }
        return "Something went wrong. Please try again."
    }

    nonisolated var apiCode: String? { (self as? APIError)?.code }
}

private nonisolated struct ErrorEnvelope: Decodable {
    struct Body: Decodable {
        let code: String
        let message: String
    }
    let error: Body
}

/// Thin typed HTTP client for the revOWL Worker.
nonisolated final class APIClient: Sendable {
    static let shared = APIClient()

    let baseURL: URL
    private let session: URLSession

    init() {
        let configured = Config.EXPO_PUBLIC_RORK_FUNCTIONS_URL
        baseURL = URL(string: configured.isEmpty ? "https://revowl-ai-hotel-revenue-backend.rork.app" : configured)
            ?? URL(string: "https://revowl-ai-hotel-revenue-backend.rork.app")!
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 75
        config.waitsForConnectivity = false
        session = URLSession(configuration: config)
    }

    var token: String? { Keychain.read("session_token") }

    func request<T: Decodable & Sendable>(
        _ method: String,
        _ path: String,
        query: [String: String] = [:],
        body: (any Encodable & Sendable)? = nil,
        authenticated: Bool = true,
        as type: T.Type = T.self
    ) async throws -> T {
        var components = URLComponents(url: baseURL.appending(path: path), resolvingAgainstBaseURL: false)
        if !query.isEmpty {
            components?.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        guard let url = components?.url else { throw APIError.decoding }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if authenticated, let token {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            req.httpBody = try JSONEncoder().encode(body)
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: req)
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch {
            throw APIError.offline
        }
        guard let http = response as? HTTPURLResponse else { throw APIError.decoding }
        guard (200..<300).contains(http.statusCode) else {
            if let env = try? JSONDecoder().decode(ErrorEnvelope.self, from: data) {
                throw APIError(status: http.statusCode, code: env.error.code, message: env.error.message)
            }
            let message = http.statusCode >= 500
                ? "Our service is having a moment. Please try again shortly."
                : "The request couldn't be completed."
            throw APIError(status: http.statusCode, code: "http_\(http.statusCode)", message: message)
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            #if DEBUG
            print("[API] decode failed for \(path): \(error)")
            #endif
            throw APIError.decoding
        }
    }

    func get<T: Decodable & Sendable>(_ path: String, query: [String: String] = [:], as type: T.Type = T.self) async throws -> T {
        try await request("GET", path, query: query, as: type)
    }

    func post<T: Decodable & Sendable>(_ path: String, json: [String: JSONValue] = [:], query: [String: String] = [:], as type: T.Type = T.self) async throws -> T {
        try await request("POST", path, query: query, body: json, as: type)
    }

    func patch<T: Decodable & Sendable>(_ path: String, json: [String: JSONValue], as type: T.Type = T.self) async throws -> T {
        try await request("PATCH", path, body: json, as: type)
    }

    func delete<T: Decodable & Sendable>(_ path: String, as type: T.Type = T.self) async throws -> T {
        try await request("DELETE", path, as: type)
    }
}
