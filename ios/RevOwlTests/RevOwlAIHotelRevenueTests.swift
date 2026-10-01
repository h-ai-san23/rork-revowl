import Foundation
import Testing
@testable import RevOwl

@MainActor
struct FormattingTests {
    @Test func addDaysCrossesMonthAndYearBoundaries() {
        #expect(Fmt.addDays("2026-01-31", 1) == "2026-02-01")
        #expect(Fmt.addDays("2026-12-31", 1) == "2027-01-01")
        #expect(Fmt.addDays("2026-03-01", -1) == "2026-02-28")
        #expect(Fmt.addDays("2028-02-28", 1) == "2028-02-29")
    }

    @Test func invalidDateIsReturnedUnchanged() {
        #expect(Fmt.addDays("not-a-date", 3) == "not-a-date")
        #expect(Fmt.day("garbage") == "garbage")
    }

    @Test func isoRoundTripIsStableInUTC() {
        let date = Fmt.date("2026-07-04")
        #expect(date != nil)
        #expect(Fmt.iso(date!) == "2026-07-04")
        #expect(Fmt.dayNumber("2026-07-04") == "4")
    }

    @Test func rangeCollapsesSingleDay() {
        #expect(Fmt.range("2026-05-01", "2026-05-01") == Fmt.day("2026-05-01"))
        #expect(Fmt.range("2026-05-01", "2026-05-03").contains("–"))
    }

    @Test func missingValuesShowDash() {
        #expect(Fmt.money(nil, "USD") == "—")
        #expect(Fmt.percent(nil) == "—")
        #expect(Fmt.shortDate(ms: nil) == "—")
        #expect(Fmt.relative(ms: nil) == "never")
        #expect(Fmt.relative(ms: 0) == "never")
    }

    @Test func parseNumberHandlesTypedInput() {
        #expect(Fmt.parseNumber("42") == 42)
        #expect(Fmt.parseNumber("  189 ") == 189)
        #expect(Fmt.parseNumber("$215") == 215)
        #expect(Fmt.parseNumber("") == nil)
        #expect(Fmt.parseNumber("abc") == nil)
        if Locale.current.decimalSeparator == "." {
            #expect(Fmt.parseNumber("1,234.50") == 1234.5)
            #expect(Fmt.parseNumber("99.9") == 99.9)
        }
    }

    @Test func trimmedAndNilIfEmpty() {
        #expect("  hotel \n".trimmed == "hotel")
        #expect("   ".nilIfEmpty == nil)
        #expect(" Inn ".nilIfEmpty == "Inn")
    }
}

@MainActor
struct JSONValueTests {
    private func encode(_ value: JSONValue) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return String(decoding: try encoder.encode(value), as: UTF8.self)
    }

    @Test func blankStringsBecomeNull() throws {
        #expect(JSONValue.from("   ") == .null)
        #expect(JSONValue.from(nil as String?) == .null)
        #expect(JSONValue.from("  Lisbon ") == .string("Lisbon"))
    }

    @Test func wholeNumbersEncodeAsIntegers() throws {
        #expect(try encode(.number(42)) == "42")
        #expect(try encode(.number(42.5)) == "42.5")
        #expect(try encode(JSONValue.from(nil as Int?)) == "null")
    }

    @Test func nestedObjectsEncode() throws {
        let body: JSONValue = ["roomCount": 12, "goals": .from(["grow_revpar"]), "website": .null]
        #expect(try encode(body) == #"{"goals":["grow_revpar"],"roomCount":12,"website":null}"#)
    }
}

@MainActor
struct OnboardingStepTests {
    @Test func serverStepsStartAtWebsite() {
        #expect(!OnboardingStep.welcome.isServerStep)
        #expect(!OnboardingStep.signIn.isServerStep)
        #expect(!OnboardingStep.property.isServerStep)
        #expect(OnboardingStep.website.isServerStep)
        #expect(OnboardingStep.briefing.isServerStep)
    }

    @Test func backNavigationStopsAtWebsite() {
        #expect(OnboardingStep.website.previous == nil)
        #expect(OnboardingStep.property.previous == nil)
        #expect(OnboardingStep.confirm.previous == .website)
        #expect(OnboardingStep.briefing.previous == .plans)
    }

    @Test func nextFollowsOrderAndEnds() {
        #expect(OnboardingStep.welcome.next == .signIn)
        #expect(OnboardingStep.locale.next == .dataImport)
        #expect(OnboardingStep.briefing.next == nil)
    }

    @Test func importStepMatchesServerRawValue() {
        #expect(OnboardingStep(rawValue: "import") == .dataImport)
        #expect(OnboardingStep.dataImport.rawValue == "import")
    }
}

@MainActor
struct OrevAndOptionsTests {
    @Test func unknownMoodFallsBackToIdle() {
        #expect(OrevState(mood: "opportunity") == .opportunity)
        #expect(OrevState(mood: "celebrating") == .celebrating)
        #expect(OrevState(mood: "something-new") == .idle)
    }

    @Test func everyOrevStateHasText() {
        for state in OrevState.allCases {
            #expect(!state.statusText.isEmpty)
            #expect(!state.accessibilityDescription.isEmpty)
        }
    }

    @Test func currencyForRegion() {
        #expect(CurrencyOptions.forRegion("US") == "USD")
        #expect(CurrencyOptions.forRegion("gb") == "GBP")
        #expect(CurrencyOptions.forRegion("") == nil)
        #expect(CurrencyOptions.forRegion(nil) == nil)
    }

    @Test func goalIdsAreUnique() {
        let ids = GoalOption.all.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test func occupancyBarIsClamped() {
        #expect(CalendarView.barFraction(nil) == 0)
        #expect(CalendarView.barFraction(-0.2) == 0)
        #expect(CalendarView.barFraction(0.5) == 0.5)
        #expect(CalendarView.barFraction(1.4) == 1)
        #expect(CalendarView.barFraction(.nan) == 0)
    }

    @Test func apiErrorFlags() {
        let limit = APIError(status: 402, code: "plan_limit", message: "Upgrade")
        #expect(limit.isPlanLimit)
        #expect(!limit.isUnauthenticated)
        #expect(limit.userMessage == "Upgrade")
        #expect(APIError(status: 401, code: "auth", message: "x").isUnauthenticated)
    }
}
