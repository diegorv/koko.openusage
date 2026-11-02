import XCTest
@testable import OpenUsage

final class AccountMergeTests: XCTestCase {
    private let work = MergedAccount(providerID: "claude", shortName: "work", colorIndex: 0)
    private let home = MergedAccount(providerID: "claude@ab12cd34", shortName: "home", colorIndex: 1)

    private func percent(_ used: Double, resetsAt: Date? = nil, periodMs: Int? = nil) -> WidgetData {
        var data = WidgetData(title: "Weekly", icon: .providerMark("claude"), kind: .percent, used: used, limit: 100)
        data.resetsAt = resetsAt
        data.periodDurationMs = periodMs
        return data
    }

    private func noData() -> WidgetData {
        var data = percent(0)
        data.hasData = false
        return data
    }

    func testTwoAccountsAverageAndKeepATickEach() {
        let merged = WidgetData.merging([
            AccountReading(account: work, data: percent(20)),
            AccountReading(account: home, data: percent(60))
        ])

        XCTAssertEqual(merged.used, 40)
        XCTAssertEqual(merged.limit, 100)
        XCTAssertEqual(merged.accountTicks, [
            AccountTick(account: work, used: 20, limit: 100),
            AccountTick(account: home, used: 60, limit: 100)
        ])
    }

    func testAccountMissingTheMetricIsLeftOutAndGetsNoTick() {
        let other = MergedAccount(providerID: "claude@ffff0000", shortName: "other", colorIndex: 2)
        let merged = WidgetData.merging([
            AccountReading(account: work, data: percent(30)),
            AccountReading(account: home, data: noData()),
            AccountReading(account: other, data: percent(50))
        ])

        XCTAssertEqual(merged.used, 40)
        XCTAssertTrue(merged.hasData)
        XCTAssertEqual(merged.accountTicks.map(\.account), [work, other])
    }

    func testNoAccountWithDataStaysNoData() {
        let merged = WidgetData.merging([
            AccountReading(account: work, data: noData()),
            AccountReading(account: home, data: noData())
        ])
        XCTAssertFalse(merged.hasData)
        XCTAssertTrue(merged.accountTicks.isEmpty)
    }

    func testMoneyMetricIsSummed() {
        func spend(_ dollars: Double, tokens: Double) -> WidgetData {
            var data = WidgetData(title: "Today", icon: .providerMark("claude"), kind: .dollars, used: 0, limit: nil)
            data.values = [MetricValue(number: dollars, kind: .dollars), MetricValue(number: tokens, kind: .count, label: "tokens")]
            return data
        }
        let merged = WidgetData.merging([
            AccountReading(account: work, data: spend(4.5, tokens: 1_000)),
            AccountReading(account: home, data: spend(1.25, tokens: 500))
        ])

        XCTAssertEqual(merged.values.map(\.number), [5.75, 1_500])
        XCTAssertTrue(merged.accountTicks.isEmpty, "unbounded rows have no bar to tick")
    }

    func testMoneyMeterInAnotherCurrencyIsLeftOutOfTheSum() {
        let third = MergedAccount(providerID: "claude@ffff0000", shortName: "third", colorIndex: 2)
        func extra(_ used: Double, _ limit: Double, currency: String?) -> WidgetData {
            var data = WidgetData(title: "Extra Usage", icon: .providerMark("claude"), kind: .dollars, used: used, limit: limit)
            data.currency = currency
            return data
        }
        let merged = WidgetData.merging([
            AccountReading(account: work, data: extra(10, 100, currency: nil)),
            AccountReading(account: home, data: extra(5, 50, currency: "EUR")),
            AccountReading(account: third, data: extra(20, 100, currency: nil))
        ])

        XCTAssertEqual(merged.used, 30)
        XCTAssertEqual(merged.limit, 200)
        XCTAssertNil(merged.currency)
    }

    func testBoundedMoneyAndCountSumUsedAndLimit() {
        let credits = { (used: Double, limit: Double) in
            WidgetData(title: "Credits", icon: .providerMark("codex"), kind: .count, used: used, limit: limit, countSuffix: "credits")
        }
        let merged = WidgetData.merging([
            AccountReading(account: work, data: credits(100, 1_000)),
            AccountReading(account: home, data: credits(300, 500))
        ])

        XCTAssertEqual(merged.used, 400)
        XCTAssertEqual(merged.limit, 1_500)
        XCTAssertEqual(merged.accountTicks.map(\.fraction), [0.1, 0.6])
    }

    func testResetIsTheSoonest() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let merged = WidgetData.merging([
            AccountReading(account: work, data: percent(10, resetsAt: now.addingTimeInterval(7_200), periodMs: 1)),
            AccountReading(account: home, data: percent(10, resetsAt: now.addingTimeInterval(3_600), periodMs: 2))
        ])

        XCTAssertEqual(merged.resetsAt, now.addingTimeInterval(3_600))
        XCTAssertEqual(merged.periodDurationMs, 2, "the pace window follows the soonest reset")
    }

    func testSingleAccountIsUnchanged() {
        let data = percent(42, resetsAt: Date(timeIntervalSince1970: 5), periodMs: 9)
        XCTAssertEqual(WidgetData.merging([AccountReading(account: work, data: data)]), data)
    }

    func testChartPointsSumByDay() {
        func trend(_ values: [Double]) -> WidgetData {
            var data = WidgetData(title: "Trend", icon: .providerMark("claude"), kind: .count, used: 0, limit: nil)
            data.isChart = true
            data.chartPoints = values.enumerated().map { MetricChartPoint(value: $1, label: "d\($0)") }
            return data
        }
        let merged = WidgetData.merging([
            AccountReading(account: work, data: trend([1, 2])),
            AccountReading(account: home, data: trend([10, 20]))
        ])
        XCTAssertEqual(merged.chartPoints.map(\.value), [11, 22])
        XCTAssertEqual(merged.chartPoints.map(\.label), ["d0", "d1"])
    }

    @MainActor
    func testShortNameOfEachRealAccountNameFormat() throws {
        func short(_ displayName: String, _ family: String) -> String {
            MergedAccount.shortName(displayName: displayName, familyName: family)
        }
        let claudeSwap = ClaudeSwapAccount(root: "/r", slot: "1", email: "alice@x.com", identityKey: "k",
                                           organizationID: "org", organizationName: "Acme Org")
        XCTAssertEqual(short(claudeSwap.displayName(), "Claude"), "Acme Org")

        let codexIdentity = try XCTUnwrap(CodexAccountIdentity(accountID: "ab12cd34ef", email: "bob@x.com"))
        let codexAlias = CodexSwapAccount(number: 1, alias: "work", identity: codexIdentity, home: "/h",
                                          mainHome: "/m", plan: nil, shareHistory: false)
        XCTAssertEqual(short(codexAlias.displayName, "Codex"), "work")
        let codexBare = CodexSwapAccount(number: 2, alias: nil, identity: codexIdentity, home: "/h",
                                         mainHome: "/m", plan: nil, shareHistory: false)
        XCTAssertEqual(short(codexBare.displayName, "Codex"), "Workspace ab12cd34")

        let hubAccount = CLIProxyHubAccount(id: "a1", authIndex: "0", provider: .claude, email: "carol@x.com")
        let hub = CLIProxyHubConfig.Hub(id: "h", label: "lab", url: "https://hub.example", managementKey: "",
                                        enabled: true, accounts: [])
        let hubName = CLIProxyHubCards.displayName(account: hubAccount, hub: hub,
                                                   hubURL: try XCTUnwrap(URL(string: hub.url)))
        XCTAssertEqual(short(hubName, "Claude"), "carol")

        XCTAssertEqual(short("Claude: dave@x.com", "Claude"), "dave")
        XCTAssertEqual(short("Claude \u{2014} Spare Org", "Claude"), "Spare Org")
        XCTAssertEqual(short("Claude", "Claude"), "Claude")
    }

    func testShortNameKeepingDetailAddsTheEmailLocalPartOrHubLabel() {
        func detailed(_ displayName: String, _ family: String) -> String {
            MergedAccount.shortName(displayName: displayName, familyName: family, keepingDetail: true)
        }
        XCTAssertEqual(detailed("Claude: Acme Org (alice@x.com)", "Claude"), "Acme Org (alice)")
        XCTAssertEqual(detailed("Codex: Workspace ab12cd34 (bob@x.com)", "Codex"), "Workspace ab12cd34 (bob)")
        XCTAssertEqual(detailed("Claude: carol@x.com (Hub lab)", "Claude"), "carol (Hub lab)")
        XCTAssertEqual(detailed("Claude: dave@x.com", "Claude"), "dave")
    }

    func testCurrencyMismatchIsLoggedOncePerDistinctMessage() throws {
        let title = "Extra Usage \(UUID().uuidString)"
        func extra(_ currency: String?) -> WidgetData {
            var data = WidgetData(title: title, icon: .providerMark("claude"), kind: .dollars, used: 1, limit: 10)
            data.currency = currency
            return data
        }
        let readings = [AccountReading(account: work, data: extra(nil)), AccountReading(account: home, data: extra("EUR"))]

        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("OpenUsageTests.AccountMerge.\(UUID().uuidString)", isDirectory: true)
        let sink = LogFile(directory: tempDir, fileName: "OpenUsage.log")
        sink.open()
        let originalSink = AppLog.sink
        AppLog.sink = sink
        AppLog.reloadLevel(.debug)
        defer {
            AppLog.sink = originalSink
            AppLog.reloadLevel()
            try? FileManager.default.removeItem(at: tempDir)
        }
        _ = WidgetData.merging(readings)
        _ = WidgetData.merging(readings)

        let log = try String(contentsOf: tempDir.appendingPathComponent("OpenUsage.log"), encoding: .utf8)
        XCTAssertEqual(log.components(separatedBy: title).count - 1, 1, "a re-render must not repeat the warning")
    }
}
