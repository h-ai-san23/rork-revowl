import Foundation

/// Encodable JSON value for request bodies that need explicit nulls or dynamic keys.
nonisolated enum JSONValue: Encodable, Sendable, Hashable,
    ExpressibleByStringLiteral, ExpressibleByIntegerLiteral, ExpressibleByFloatLiteral,
    ExpressibleByBooleanLiteral, ExpressibleByNilLiteral, ExpressibleByArrayLiteral, ExpressibleByDictionaryLiteral {
    case string(String)
    case number(Double)
    case bool(Bool)
    case null
    case array([JSONValue])
    case object([String: JSONValue])

    init(stringLiteral value: String) { self = .string(value) }
    init(integerLiteral value: Int) { self = .number(Double(value)) }
    init(floatLiteral value: Double) { self = .number(value) }
    init(booleanLiteral value: Bool) { self = .bool(value) }
    init(nilLiteral: ()) { self = .null }
    init(arrayLiteral elements: JSONValue...) { self = .array(elements) }
    init(dictionaryLiteral elements: (String, JSONValue)...) {
        self = .object(Dictionary(elements, uniquingKeysWith: { _, last in last }))
    }

    static func from(_ value: String?) -> JSONValue {
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return .null }
        return .string(value.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    static func from(_ value: Double?) -> JSONValue { value.map { .number($0) } ?? .null }
    static func from(_ value: Int?) -> JSONValue { value.map { .number(Double($0)) } ?? .null }
    static func from(_ values: [String]) -> JSONValue { .array(values.map { .string($0) }) }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .string(let s): try c.encode(s)
        case .number(let n):
            if n.rounded() == n, abs(n) < 1e15 { try c.encode(Int64(n)) } else { try c.encode(n) }
        case .bool(let b): try c.encode(b)
        case .null: try c.encodeNil()
        case .array(let a): try c.encode(a)
        case .object(let o): try c.encode(o)
        }
    }
}
