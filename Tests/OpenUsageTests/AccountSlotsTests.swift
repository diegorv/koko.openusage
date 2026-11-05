import XCTest
@testable import OpenUsage

final class AccountSlotsTests: XCTestCase {
    private let me = MergedAccount(providerID: "claude", shortName: "eu", colorIndex: 0)
    private let leo = MergedAccount(providerID: "claude@ab12cd34", shortName: "leo", colorIndex: 1)
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let weekMs = 7 * 24 * 3_600_000

    private func percent(_ used: Double, resetsIn hours: Double, mode: WidgetDisplayMode = .remaining) -> WidgetData {
        var data = WidgetData(title: "Weekly", icon: .providerMark("claude"), kind: .percent, used: used, limit: 100)
        data.resetsAt = now.addingTimeInterval(hours * 3600)
        data.periodDurationMs = weekMs
        data.displayMode = mode
        return data
    }

    private func merged(_ mine: WidgetData, _ his: WidgetData) -> WidgetData {
        WidgetData.merging([AccountReading(account: me, data: mine), AccountReading(account: leo, data: his)])
    }

    func testEachAccountKeepsItsOwnValueAndReset() {
        let data = merged(percent(38, resetsIn: 110), percent(73, resetsIn: 74))

        XCTAssertTrue(data.showsAccountSlots)
        XCTAssertEqual(data.accountRows.map(\.account), [me, leo])
        XCTAssertEqual(data.accountRows.map(\.data.fraction), [0.62, 0.27])
        XCTAssertEqual(data.accountRows.map(\.data.resetsAt), [
            now.addingTimeInterval(110 * 3600), now.addingTimeInterval(74 * 3600)
        ])
        XCTAssertEqual(data.accountRows[0].data.boundedHeadline, "62% left")
    }

    func testSlotsFollowTheUsedLeftSetting() {
        let data = merged(percent(38, resetsIn: 110, mode: .used), percent(73, resetsIn: 74, mode: .used))

        XCTAssertEqual(data.accountRows.map(\.data.fraction), [0.38, 0.73])
        XCTAssertEqual(data.accountRows[1].data.boundedHeadline, "73% used")
    }

    func testAccountMissingTheMetricGetsNoSlot() {
        var missing = percent(0, resetsIn: 74)
        missing.hasData = false

        XCTAssertEqual(merged(percent(38, resetsIn: 110), missing).accountRows.map(\.account), [me])
    }

    /// A pace projection would turn this red ("Limit in …"): 68% used with 3 of 7 days gone.
    func testMergedPercentRowHasNoPaceVerdict() {
        let data = merged(percent(36, resetsIn: 110), percent(100, resetsIn: 74))

        XCTAssertEqual(data.meterState(now: now), .level(.normal))
    }

    func testMergedPercentRowColorsByLevel() {
        XCTAssertEqual(merged(percent(70, resetsIn: 110), percent(90, resetsIn: 74)).meterState(now: now), .level(.warning))
        XCTAssertEqual(merged(percent(85, resetsIn: 110), percent(95, resetsIn: 74)).meterState(now: now), .level(.critical))
        XCTAssertEqual(merged(percent(100, resetsIn: 110), percent(100, resetsIn: 74)).meterState(now: now), .spent)
    }

    func testBoundedMoneyRowKeepsTicksNotSlots() {
        func dollars(_ used: Double) -> WidgetData {
            WidgetData(title: "Extra", icon: .providerMark("claude"), kind: .dollars, used: used, limit: 100)
        }
        let data = merged(dollars(10), dollars(20))

        XCTAssertFalse(data.showsAccountSlots)
        XCTAssertTrue(data.showsAccountTicks)
    }

    func testAnonymizedRowHidesAccountNamesAndKeepsValues() {
        let data = merged(percent(38, resetsIn: 110), percent(73, resetsIn: 74)).anonymizingAccounts()

        XCTAssertEqual(data.accountRows.map(\.account.shortName), ["Account 1", "Account 2"])
        XCTAssertEqual(data.accountRows.map(\.data.fraction), [0.62, 0.27])
    }

    func testALoneAccountOnAFamilyCardGetsASlotAndNoPace() {
        let data = WidgetData.soloAccount(AccountReading(account: me, data: percent(95, resetsIn: 110)))

        XCTAssertEqual(data.accountRows.map(\.account), [me])
        XCTAssertEqual(data.meterState(now: now), .level(.critical))
    }

    func testAnAccountWithNoReadingsStaysVisibleAndMarksTheTotal() {
        var failed = percent(0, resetsIn: 74)
        failed.hasData = false
        let data = WidgetData.merging([
            AccountReading(account: me, data: percent(37, resetsIn: 110)),
            AccountReading(account: leo, data: failed, isUnavailable: true)
        ])

        XCTAssertEqual(data.used, 37)
        XCTAssertEqual(data.accountRows.map(\.account), [me])
        XCTAssertEqual(data.unavailableAccounts, [leo])
        XCTAssertEqual(data.anonymizingAccounts().unavailableAccounts.map(\.shortName), ["Account 2"])
    }

    func testAnAccountLackingOnlyThisMetricIsNotUnavailable() {
        var missing = percent(0, resetsIn: 74)
        missing.hasData = false

        XCTAssertEqual(merged(percent(37, resetsIn: 110), missing).unavailableAccounts, [])
    }

    func testAllAccountsUnavailableStaysNoData() {
        var failed = percent(0, resetsIn: 74)
        failed.hasData = false
        let data = WidgetData.merging([
            AccountReading(account: me, data: failed, isUnavailable: true),
            AccountReading(account: leo, data: failed, isUnavailable: true)
        ])

        XCTAssertFalse(data.hasData)
    }

    func testASpentAccountReadsUsedUpWithAShortReset() {
        let data = merged(percent(100, resetsIn: 74), percent(37, resetsIn: 110))

        XCTAssertEqual(data.accountRows[0].data.accountSummary(showsValue: true, now: now), "Used Up · 3d 2h")
        XCTAssertEqual(data.accountRows[1].data.accountSummary(showsValue: true, now: now), "63% left · 4d 14h")
    }

    func testALoneAccountLineLeavesTheValueToTheHeader() {
        let data = WidgetData.soloAccount(AccountReading(account: me, data: percent(37, resetsIn: 110)))

        XCTAssertEqual(data.accountRows[0].data.accountSummary(showsValue: false, now: now), "4d 14h")
    }

    func testAccountsReadAlikeOnlyWhenEveryoneMatches() {
        XCTAssertTrue(merged(percent(0, resetsIn: 74), percent(0, resetsIn: 110)).accountsReadAlike)
        XCTAssertFalse(merged(percent(0, resetsIn: 74), percent(5, resetsIn: 110)).accountsReadAlike)
        var failed = percent(0, resetsIn: 74)
        failed.hasData = false
        let partial = WidgetData.merging([
            AccountReading(account: me, data: percent(0, resetsIn: 110)),
            AccountReading(account: leo, data: percent(0, resetsIn: 74)),
            AccountReading(account: MergedAccount(providerID: "claude@x", shortName: "x", colorIndex: 2),
                           data: failed, isUnavailable: true)
        ])
        XCTAssertFalse(partial.accountsReadAlike, "an account with no data must stay visible")
    }

    func testSingleAccountRowIsUnchanged() {
        let data = WidgetData.merging([AccountReading(account: me, data: percent(36, resetsIn: 110))])

        XCTAssertFalse(data.showsAccountSlots)
        XCTAssertTrue(data.accountRows.isEmpty)
    }
}
