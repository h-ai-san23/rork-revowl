import Foundation
import Security
import CryptoKit

class HotelRegistrationService {
    private static let registeredHotelsKey = "registeredHotelFingerprints"
    private static let deviceIdKeychainKey = "com.revowl.deviceId"

    static let shared = HotelRegistrationService()

    func deviceId() -> String {
        if let existing = readKeychainValue(key: Self.deviceIdKeychainKey) {
            return existing
        }
        let newId = UUID().uuidString
        saveKeychainValue(key: Self.deviceIdKeychainKey, value: newId)
        return newId
    }

    func hotelFingerprint(name: String, latitude: Double, longitude: Double) -> String {
        let normalizedName = name.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "the ", with: "")
            .replacingOccurrences(of: " ", with: "")
        let roundedLat = (latitude * 1000).rounded() / 1000
        let roundedLon = (longitude * 1000).rounded() / 1000
        let raw = "\(normalizedName)|\(roundedLat)|\(roundedLon)"
        let digest = SHA256.hash(data: Data(raw.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    func isHotelAlreadyRegistered(name: String, latitude: Double, longitude: Double) -> Bool {
        let fingerprint = hotelFingerprint(name: name, latitude: latitude, longitude: longitude)
        let registered = registeredFingerprints()
        return registered.contains(fingerprint)
    }

    func registerHotel(name: String, latitude: Double, longitude: Double) -> String {
        let fingerprint = hotelFingerprint(name: name, latitude: latitude, longitude: longitude)
        var registered = registeredFingerprints()
        if !registered.contains(fingerprint) {
            registered.append(fingerprint)
            saveRegisteredFingerprints(registered)
        }
        let device = deviceId()
        return "\(fingerprint.prefix(12))-\(device.prefix(8))".uppercased()
    }

    func unregisterHotel(name: String, latitude: Double, longitude: Double) {
        let fingerprint = hotelFingerprint(name: name, latitude: latitude, longitude: longitude)
        var registered = registeredFingerprints()
        registered.removeAll { $0 == fingerprint }
        saveRegisteredFingerprints(registered)
    }

    func unregisterCurrentHotel(registrationId: String) {
        guard !registrationId.isEmpty else { return }
        let fingerprintPrefix = String(registrationId.prefix(12)).lowercased()
        var registered = registeredFingerprints()
        registered.removeAll { $0.hasPrefix(fingerprintPrefix) }
        saveRegisteredFingerprints(registered)
    }

    private func registeredFingerprints() -> [String] {
        UserDefaults.standard.stringArray(forKey: Self.registeredHotelsKey) ?? []
    }

    private func saveRegisteredFingerprints(_ fingerprints: [String]) {
        UserDefaults.standard.set(fingerprints, forKey: Self.registeredHotelsKey)
    }

    private func readKeychainValue(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func saveKeychainValue(key: String, value: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }
}
