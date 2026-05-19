import Foundation

nonisolated struct DiscoveredCompetitor: Codable, Sendable, Identifiable, Hashable {
    let id: String
    var name: String
    var latitude: Double
    var longitude: Double
    var distance: Double
    var address: String?

    init(
        id: String = UUID().uuidString, name: String = "",
        latitude: Double = 0, longitude: Double = 0,
        distance: Double = 0, address: String? = nil
    ) {
        self.id = id; self.name = name; self.latitude = latitude
        self.longitude = longitude; self.distance = distance; self.address = address
    }
}
