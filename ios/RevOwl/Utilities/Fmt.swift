import Foundation

/// Formatting helpers. Property dates are calendar dates (YYYY-MM-DD). They are parsed and
/// displayed in UTC so a stay date never shifts because of the device's time zone.
enum Fmt {
    static let utcCalendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        c.firstWeekday = Calendar.current.firstWeekday
        return c
    }()

    private static func makeFormatter(_ timeZone: TimeZone, calendar: Calendar) -> DateFormatter {
        let f = DateFormatter()
        f.calendar = calendar
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = timeZone
        f.dateFormat = "yyyy-MM-dd"
        return f
    }

    private static let isoFormatter = makeFormatter(utcCalendar.timeZone, calendar: utcCalendar)
    private static let localFormatter = makeFormatter(.current, calendar: Calendar(identifier: .gregorian))

    private static var utcStyle: Date.FormatStyle {
        Date.FormatStyle(calendar: utcCalendar, timeZone: utcCalendar.timeZone)
    }

    /// UTC midnight for an ISO calendar date.
    static func date(_ iso: String) -> Date? {
        isoFormatter.date(from: String(iso.prefix(10)))
    }

    /// Noon UTC — safe for charts that label in the device time zone.
    static func chartDate(_ iso: String) -> Date {
        (date(iso) ?? .now).addingTimeInterval(12 * 3600)
    }

    static func iso(_ date: Date) -> String { isoFormatter.string(from: date) }

    /// Converts a DatePicker (device-local) date into an ISO calendar date.
    static func localISO(_ date: Date) -> String { localFormatter.string(from: date) }

    /// Converts an ISO calendar date to a device-local date for DatePicker.
    static func localDate(_ iso: String) -> Date? { localFormatter.date(from: String(iso.prefix(10))) }

    static func addDays(_ iso: String, _ days: Int) -> String {
        guard let d = date(iso), let n = utcCalendar.date(byAdding: .day, value: days, to: d) else { return iso }
        return Self.iso(n)
    }

    static func day(_ iso: String) -> String {
        guard let d = date(iso) else { return iso }
        return d.formatted(utcStyle.weekday(.abbreviated).month(.abbreviated).day())
    }

    static func dayMonth(_ date: Date) -> String {
        date.formatted(Date.FormatStyle().month(.abbreviated).day())
    }

    static func weekdayShort(_ iso: String) -> String {
        guard let d = date(iso) else { return "" }
        return d.formatted(utcStyle.weekday(.abbreviated))
    }

    static func dayNumber(_ iso: String) -> String {
        guard let d = date(iso) else { return "" }
        return String(utcCalendar.component(.day, from: d))
    }

    static func longDay(_ iso: String) -> String {
        guard let d = date(iso) else { return iso }
        return d.formatted(utcStyle.weekday(.wide).month(.wide).day())
    }

    static func monthTitle(_ iso: String) -> String {
        guard let d = date(iso) else { return iso }
        return d.formatted(utcStyle.month(.wide).year())
    }

    static func range(_ start: String, _ end: String) -> String {
        start == end ? day(start) : "\(day(start)) – \(day(end))"
    }

    static func money(_ value: Double?, _ currency: String) -> String {
        guard let value else { return "—" }
        let digits = value >= 1000 ? 0...0 : 0...2
        return value.formatted(.currency(code: currency).precision(.fractionLength(digits)))
    }

    static func percent(_ value: Double?, digits: Int = 0) -> String {
        guard let value else { return "—" }
        return value.formatted(.percent.precision(.fractionLength(digits)))
    }

    static func relative(ms: Double?) -> String {
        guard let ms, ms > 0 else { return "never" }
        return Date(timeIntervalSince1970: ms / 1000).formatted(.relative(presentation: .named))
    }

    static func number(_ value: Int) -> String { value.formatted(.number) }

    static func shortDate(ms: Double?) -> String {
        guard let ms else { return "—" }
        return Date(timeIntervalSince1970: ms / 1000).formatted(date: .abbreviated, time: .omitted)
    }

    /// Parses user-typed numbers such as "1,234.50" or "1.234,50" using the device locale.
    static func parseNumber(_ raw: String) -> Double? {
        let dec = Locale.current.decimalSeparator ?? "."
        var t = raw.trimmed.filter { $0.isNumber || $0 == "." || $0 == "," }
        if dec == "," {
            t = t.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
        } else {
            t = t.replacingOccurrences(of: ",", with: "")
        }
        return Double(t)
    }
}

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
    var nilIfEmpty: String? { trimmed.isEmpty ? nil : trimmed }
}
