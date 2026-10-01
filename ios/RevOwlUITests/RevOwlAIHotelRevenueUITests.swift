import XCTest

/// End-to-end walk through every screen against the live backend, using a throwaway
/// device-only account that the test deletes at the end.
final class RevOwlAIHotelRevenueUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: Helpers

    /// `reset` signs out and forgets the device account. Later steps relaunch without it,
    /// so the app resumes on the same account and onboarding step (saved on the server).
    @MainActor
    private func launch(reset: Bool = false) {
        app = XCUIApplication()
        app.launchArguments = reset ? ["-uitestReset", "-uitestStill"] : ["-uitestStill"]
        app.launch()
    }

    /// Single-line fields are text fields; multi-line (axis: .vertical) fields are text views.
    @MainActor
    private func field(_ id: String, timeout: TimeInterval = 10) -> XCUIElement {
        let tf = app.textFields[id]
        if tf.waitForExistence(timeout: timeout) { return tf }
        let tv = app.textViews[id]
        XCTAssertTrue(tv.waitForExistence(timeout: 2), "Field \(id) not found")
        return tv
    }

    @MainActor
    private func waitFocused(_ element: XCUIElement, _ message: String, timeout: TimeInterval = 5) {
        let focused = NSPredicate(format: "hasKeyboardFocus == true")
        let exp = XCTNSPredicateExpectation(predicate: focused, object: element)
        XCTAssertEqual(XCTWaiter().wait(for: [exp], timeout: timeout), .completed, message)
    }

    /// True when the element is on screen with a real, finite size and can receive a tap.
    @MainActor
    private func isTappable(_ e: XCUIElement) -> Bool {
        guard e.exists else { return false }
        let f = e.frame
        guard !f.isNull, !f.isInfinite, f.width.isFinite, f.height.isFinite, f.width > 1, f.height > 1 else { return false }
        return e.isHittable
    }

    /// Closes the keyboard if it's showing, using the Done bar when available.
    @MainActor
    private func dismissKeyboardIfShown() {
        guard app.keyboards.firstMatch.exists else { return }
        let done = app.buttons["keyboard.done"].firstMatch
        if isTappable(done) {
            done.tap()
        } else if app.keyboards.buttons["Return"].exists, isTappable(app.keyboards.buttons["Return"]) {
            app.keyboards.buttons["Return"].tap()
        } else {
            app.swipeDown()
        }
        _ = app.keyboards.firstMatch.waitForNonExistence(timeout: 3)
    }

    /// Scrolls until the element is visible and not covered by the keyboard.
    @MainActor
    private func reveal(_ e: XCUIElement, name: String) {
        if isTappable(e) { return }
        dismissKeyboardIfShown()
        var tries = 0
        while !isTappable(e) && tries < 6 {
            app.swipeUp()
            tries += 1
        }
        tries = 0
        while !isTappable(e) && tries < 6 {
            app.swipeDown()
            tries += 1
        }
        XCTAssertTrue(isTappable(e), "\(name) should be visible and tappable")
    }

    /// Taps an element after confirming it's visible, so failures name the element.
    @MainActor
    private func tap(_ e: XCUIElement, _ name: String) {
        reveal(e, name: name)
        e.tap()
    }

    /// Taps the field's outer box near its right edge, away from the text line —
    /// the area that previously didn't open the keyboard. Falls back to a normal tap.
    @MainActor
    private func tapBoxPadding(id: String, field f: XCUIElement) {
        let box = app.descendants(matching: .any)["\(id).box"]
        if isTappable(box), box.frame.width > 20, box.frame.height > 20 {
            box.coordinate(withNormalizedOffset: CGVector(dx: 0.94, dy: 0.15)).tap()
        } else {
            f.tap()
        }
    }

    @MainActor
    private func tapAndType(_ id: String, _ text: String, viaPadding: Bool = true) {
        let f = field(id)
        reveal(f, name: "Field \(id)")
        if viaPadding { tapBoxPadding(id: id, field: f) } else { f.tap() }
        waitFocused(f, "Tapping \(id) should focus it and bring up the keyboard")
        f.typeText(text)
    }

    @MainActor
    private func waitEnabled(_ element: XCUIElement, timeout: TimeInterval) {
        let exp = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true AND isEnabled == true"), object: element)
        XCTAssertEqual(XCTWaiter().wait(for: [exp], timeout: timeout), .completed, "\(element) never became enabled")
    }

    @MainActor
    private func waitGone(_ element: XCUIElement, timeout: TimeInterval) {
        let exp = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: element)
        XCTAssertEqual(XCTWaiter().wait(for: [exp], timeout: timeout), .completed, "\(element) should have disappeared")
    }

    @MainActor
    private func waitText(_ fragment: String, timeout: TimeInterval) {
        let match = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS[c] %@", fragment)).firstMatch
        XCTAssertTrue(match.waitForExistence(timeout: timeout), "Expected to see “\(fragment)”")
    }

    @MainActor
    private func primary(timeout: TimeInterval = 20) {
        let button = app.buttons["step.primary"]
        waitEnabled(button, timeout: timeout)
        if !isTappable(button) { dismissKeyboardIfShown() }
        tap(button, "Continue button")
    }

    @MainActor
    private func expectStep(_ title: String, timeout: TimeInterval = 20) {
        let label = app.staticTexts["onboarding.stepLabel"]
        let exp = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label CONTAINS %@", title), object: label)
        XCTAssertEqual(XCTWaiter().wait(for: [exp], timeout: timeout), .completed, "Expected onboarding step \(title)")
    }

    @MainActor
    private func openTab(_ name: String) {
        let tab = app.tabBars.buttons[name]
        if tab.waitForExistence(timeout: 5) { tab.tap() } else { app.buttons[name].firstMatch.tap() }
    }

    @MainActor
    private func scrollTo(_ element: XCUIElement, maxSwipes: Int = 8) {
        var swipes = 0
        while swipes < maxSwipes {
            if element.exists, element.isHittable { return }
            app.swipeUp()
            swipes += 1
        }
    }

    @MainActor
    private func goBack() {
        app.navigationBars.buttons.element(boundBy: 0).tap()
    }

    /// Gives the app a moment to save the onboarding step to the server before the next
    /// test relaunches it (the step is saved in the background after each Continue).
    @MainActor
    private func settle() {
        Thread.sleep(forTimeInterval: 2)
    }

    // MARK: Ordered journey
    //
    // XCTest runs methods alphabetically, so the numbered steps below run in order and share
    // one throwaway device account. Each step relaunches the app, which resumes where setup
    // left off, so a failure names the exact screen that broke.

    @MainActor
    func test01_WelcomeAndSignIn() throws {
        launch(reset: true)
        let start = app.buttons["welcome.start"]
        XCTAssertTrue(start.waitForExistence(timeout: 30), "Welcome screen should appear")
        XCTAssertTrue(app.staticTexts["Hi, I'm Orev."].exists, "Orev greeting should show")
        start.tap()
        let device = app.buttons["signin.device"]
        XCTAssertTrue(device.waitForExistence(timeout: 10), "Sign-in screen should appear")
        device.tap()
        XCTAssertTrue(app.textFields["property.search"].waitForExistence(timeout: 30), "Property search should appear after sign-in")
    }

    @MainActor
    func test02_PropertySearchAndInviteAlert() throws {
        launch()
        XCTAssertTrue(app.textFields["property.search"].waitForExistence(timeout: 30), "Should resume on property step")
        let secondary = app.buttons["step.secondary"]
        XCTAssertTrue(secondary.waitForExistence(timeout: 10), "Invite code button should exist")
        secondary.tap()
        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 5), "Invite alert should open")
        let code = alert.textFields.firstMatch
        XCTAssertTrue(code.waitForExistence(timeout: 5), "Invite alert should have a text field")
        code.tap()
        code.typeText("ABC123")
        alert.buttons["Cancel"].tap()
        waitGone(alert, timeout: 5)

        tapAndType("property.search", "UITest Harbor Inn")
        primary()
        expectStep("Website", timeout: 30)
        settle()
    }

    @MainActor
    func test03_WebsiteFieldAndSkip() throws {
        launch()
        expectStep("Website", timeout: 30)
        tapAndType("website.url", "example")
        app.buttons["step.secondary"].tap()
        expectStep("Details")
        settle()
    }

    @MainActor
    func test04_ConfirmDetailsFields() throws {
        launch()
        expectStep("Details", timeout: 30)
        XCTAssertEqual(field("field.propertyname").value as? String, "UITest Harbor Inn", "Name should be prefilled")
        tapAndType("field.city", "Lisbon")
        tapAndType("field.country", "Portugal")
        tapAndType("field.address", "1 Harbour Road")
        tapAndType("field.phone", "5550100")
        let done = app.buttons["keyboard.done"].firstMatch
        XCTAssertTrue(done.waitForExistence(timeout: 3), "Phone pad should have a Done button")
        if isTappable(done) {
            done.tap()
            XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 3), "Done should close the phone pad")
        } else {
            dismissKeyboardIfShown()
        }
        primary()
        expectStep("Rooms")
        settle()
    }

    @MainActor
    func test05_RoomsNumberPadStepperAndBack() throws {
        launch()
        expectStep("Rooms", timeout: 30)
        tapAndType("rooms.count", "24")
        app.buttons["rooms.plus"].tap()
        XCTAssertEqual(field("rooms.count").value as? String, "25", "Plus should add a room")
        app.buttons["rooms.minus"].tap()
        XCTAssertEqual(field("rooms.count").value as? String, "24", "Minus should remove a room")

        app.buttons["onboarding.back"].tap()
        expectStep("Details")
        XCTAssertEqual(field("field.city").value as? String, "Lisbon", "Saved city should be kept when going back")
        primary()
        expectStep("Rooms")
        tapAndType("rooms.count", "24")
        primary()
        expectStep("Currency")
        settle()
    }

    @MainActor
    func test06_LocaleTimeZoneSearch() throws {
        launch()
        expectStep("Currency", timeout: 30)
        app.buttons["locale.timeZone"].tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5), "Time zone sheet should have a search field")
        search.tap()
        search.typeText("Lisbon")
        let zone = app.buttons["tz.Europe/Lisbon"]
        XCTAssertTrue(zone.waitForExistence(timeout: 5), "Search should find Europe/Lisbon")
        zone.tap()
        waitGone(search, timeout: 5)
        XCTAssertTrue(app.buttons["locale.timeZone"].label.contains("Lisbon"), "Chosen zone should be shown")
        primary()
        expectStep("Your data")
        settle()
    }

    @MainActor
    func test07_ImportSampleAndManualDay() throws {
        launch()
        expectStep("Your data", timeout: 30)
        app.buttons["data.loadSample"].tap()
        waitText("Sample data loaded", timeout: 30)

        app.buttons["data.addDay"].tap()
        tapAndType("manual.roomsSold", "10", viaPadding: false)
        tapAndType("manual.revenue", "1500", viaPadding: false)
        app.buttons["manual.save"].tap()
        waitGone(app.buttons["manual.save"], timeout: 20)
        waitText("Saved. Your metrics are updated.", timeout: 5)
        primary()
        expectStep("Competitors")
        settle()
    }

    @MainActor
    func test08_CompetitorsAddByName() throws {
        launch()
        expectStep("Competitors", timeout: 30)
        tapAndType("competitors.manualName", "UITest Rival Hotel")
        app.buttons["competitors.add"].tap()
        XCTAssertTrue(app.staticTexts["UITest Rival Hotel"].waitForExistence(timeout: 30), "Added competitor should be listed")
        primary(timeout: 60)
        expectStep("Goals")
        settle()
    }

    @MainActor
    func test09_GoalsOverviewPlansBriefing() throws {
        launch()
        expectStep("Goals", timeout: 30)
        app.buttons["goal.grow_revpar"].tap()
        app.buttons["goal.fill_midweek"].tap()
        primary()
        expectStep("Overview")
        primary()
        expectStep("Plans")
        let notNow = app.buttons["step.secondary"]
        XCTAssertTrue(notNow.waitForExistence(timeout: 15), "Plans should offer Not now")
        notNow.tap()
        expectStep("First briefing")
        primary(timeout: 120)
        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 30), "Dashboard should open")
    }

    @MainActor
    func test10_TodayBriefing() throws {
        launch()
        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 30), "Should open on Today")
        let quickAsk = app.buttons["How did last week go?"]
        let deadline = Date().addingTimeInterval(60)
        while !quickAsk.exists && Date() < deadline {
            app.swipeUp()
            _ = quickAsk.waitForExistence(timeout: 3)
        }
        XCTAssertTrue(quickAsk.exists, "Briefing should load with quick questions")
    }

    @MainActor
    func test11_MarketManualRate() throws {
        launch()
        openTab("Market")
        XCTAssertTrue(app.navigationBars["Market"].waitForExistence(timeout: 15), "Market should open")
        let day = app.buttons["market.day"].firstMatch
        XCTAssertTrue(day.waitForExistence(timeout: 30), "Stay dates should be listed even without public rates")
        scrollTo(day)
        day.tap()
        let edit = app.buttons["market.editRate"].firstMatch
        XCTAssertTrue(edit.waitForExistence(timeout: 10), "Day sheet should have edit buttons")
        edit.tap()
        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 5), "Rate alert should open")
        let rate = alert.textFields.firstMatch
        rate.tap()
        rate.typeText("199")
        alert.buttons["Save"].tap()
        waitGone(app.buttons["market.editRate"].firstMatch, timeout: 20)
    }

    @MainActor
    func test12_CalendarAddEvent() throws {
        launch()
        openTab("Calendar")
        XCTAssertTrue(app.navigationBars["Calendar"].waitForExistence(timeout: 15), "Calendar should open")
        let add = app.buttons["calendar.add"]
        XCTAssertTrue(add.waitForExistence(timeout: 10), "Add event button should exist")
        add.tap()
        tapAndType("event.title", "UITest Expo", viaPadding: false)
        tapAndType("event.venue", "Convention Center", viaPadding: false)
        tapAndType("event.source", "example.com/expo", viaPadding: false)
        app.buttons["event.save"].tap()
        waitGone(app.buttons["event.save"], timeout: 20)
        let added = app.staticTexts["UITest Expo"]
        XCTAssertTrue(added.waitForExistence(timeout: 15), "New event should be listed")
    }

    @MainActor
    func test13_AskOrev() throws {
        launch()
        openTab("Ask Orev")
        tapAndType("ask.input", "How did last week go?")
        app.buttons["ask.send"].tap()
        let answer = app.descendants(matching: .any).matching(NSPredicate(format: "label == 'Orev answered'")).firstMatch
        XCTAssertTrue(answer.waitForExistence(timeout: 120), "Orev should answer")
    }

    @MainActor
    func test14_PropertyDetailsAndCompetitors() throws {
        launch()
        openTab("Property")
        XCTAssertTrue(app.navigationBars["Property"].waitForExistence(timeout: 15), "Property should open")
        app.staticTexts["Details"].firstMatch.tap()
        let city = field("profile.city")
        city.tap()
        waitFocused(city, "Details city field should focus")
        city.typeText(" Centro")
        let rooms = field("profile.rooms")
        rooms.tap()
        waitFocused(rooms, "Rooms field should focus")
        app.buttons["profile.save"].tap()
        XCTAssertTrue(app.navigationBars["Property"].waitForExistence(timeout: 20), "Save should return to Property")

        app.staticTexts["Competitors"].firstMatch.tap()
        let name = field("manageCompetitors.name")
        name.tap()
        waitFocused(name, "Competitor name field inside the list should focus, not trigger Add")
        name.typeText("UITest Second Rival")
        app.buttons["manageCompetitors.add"].tap()
        XCTAssertTrue(app.staticTexts["UITest Second Rival"].waitForExistence(timeout: 20), "Second competitor should be listed")
        goBack()
    }

    @MainActor
    func test15_PropertyTeamLocalePlan() throws {
        launch()
        openTab("Property")
        XCTAssertTrue(app.navigationBars["Property"].waitForExistence(timeout: 15), "Property should open")
        app.staticTexts["Team"].firstMatch.tap()
        let create = app.buttons["Create invite code"]
        XCTAssertTrue(create.waitForExistence(timeout: 10), "Team should offer invite codes")
        create.tap()
        let shareOrLimit = app.buttons["Share code"].waitForExistence(timeout: 20) || app.buttons["See plans"].exists
        XCTAssertTrue(shareOrLimit, "Invite should be created or show the plan limit")
        goBack()

        app.staticTexts["Currency & time zone"].firstMatch.tap()
        XCTAssertTrue(app.buttons["locale.timeZone"].waitForExistence(timeout: 10), "Currency screen should open")
        goBack()

        let plan = app.staticTexts["Start a 7-day free trial"].firstMatch
        XCTAssertTrue(plan.waitForExistence(timeout: 10), "Plan row should show")
        plan.tap()
        let refresh = app.buttons["Refresh subscription status"]
        XCTAssertTrue(refresh.waitForExistence(timeout: 10), "Plan screen should open")
        refresh.tap()
        goBack()
    }

    @MainActor
    func test16_DeleteAccount() throws {
        launch()
        openTab("Property")
        XCTAssertTrue(app.navigationBars["Property"].waitForExistence(timeout: 15), "Property should open")
        let delete = app.buttons["Delete account"]
        scrollTo(delete)
        delete.tap()
        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 5), "Delete confirmation should appear")
        alert.buttons["Delete"].tap()
        XCTAssertTrue(app.buttons["welcome.start"].waitForExistence(timeout: 30), "Should return to Welcome after deletion")
    }
}
