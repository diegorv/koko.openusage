import XCTest
@testable import OpenUsage

/// Money values carry an optional ISO 4217 code; a missing code means USD. Claude's extra usage
/// reports `extra_usage.currency` (e.g. "BRL"), which must reach every surface and the limits API.
@MainActor
final class MoneyCurrencyTests: XCTestCase {
    // MARK: - Model and persistence

    func testOldSnapshotWithoutCurrencyDecodesAsUSD() throws {
        let json = #"""
        [
          {"type":"progress","label":"Extra usage spent","used":5,"limit":10,"format":{"kind":"dollars"}},
          {"type":"values","label":"Extra usage spent","values":[{"number":12.5,"kind":"dollars","estimated":false}]}
        ]
        """#
        let lines = try JSONDecoder().decode([MetricLine].self, from: Data(json.utf8))

        guard case .progress(_, _, _, let format, _, _, _) = lines[0] else { return XCTFail("Expected progress") }
        XCTAssertEqual(format, .dollars())
        XCTAssertNil(format.currency)
        guard case .values(_, let values, _, _, _, _) = lines[1] else { return XCTFail("Expected values") }
        XCTAssertNil(values.first?.currency)
    }

    func testCurrencyRoundTripsThroughCodable() throws {
        let lines: [MetricLine] = [
            .progress(label: "Extra usage spent", used: 5, limit: 20, format: .dollars(currency: "BRL")),
            .values(label: "Extra usage spent", values: [MetricValue(number: 12.5, kind: .dollars, currency: "BRL")])
        ]
        let decoded = try JSONDecoder().decode([MetricLine].self, from: JSONEncoder().encode(lines))
        XCTAssertEqual(decoded, lines)
    }

    func testUSDMoneyEncodesWithoutACurrencyKey() throws {
        let data = try JSONEncoder().encode(ProgressFormat.dollars())
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(object["kind"] as? String, "dollars")
        XCTAssertNil(object["currency"])
    }

    // MARK: - Formatting

    func testFormatterShowsTheValuesCurrency() {
        XCTAssertEqual(MetricFormatter.number(20, kind: .dollars, style: .full, currency: "BRL"), "R$20.00")
        XCTAssertEqual(MetricFormatter.number(20, kind: .dollars, style: .row, currency: "BRL"), "R$20.00")
        XCTAssertEqual(MetricFormatter.number(129.81, kind: .dollars, style: .tray, currency: "BRL"), "R$130")
        XCTAssertEqual(MetricFormatter.number(2059.07, kind: .dollars, style: .row, currency: "BRL"), "R$2.1K")
        XCTAssertEqual(MetricFormatter.number(2059.07, kind: .dollars, style: .full, currency: "BRL"), "R$2,059.07")
        // USD, explicit or absent, keeps the dollar sign.
        XCTAssertEqual(MetricFormatter.number(20, kind: .dollars, style: .full, currency: "USD"), "$20.00")
        XCTAssertEqual(MetricFormatter.number(20, kind: .dollars, style: .full), "$20.00")
        XCTAssertEqual(
            MetricFormatter.string(for: MetricValue(number: 4.08, kind: .dollars, currency: "BRL"), style: .row),
            "R$4.08"
        )
    }

    func testBoundedBRLMeterRendersRealSignOnEverySurface() async {
        let data = await resolved(line: .progress(
            label: "Extra usage spent", used: 5, limit: 20, format: .dollars(currency: "BRL")
        ))
        XCTAssertEqual(data.currency, "BRL")
        // The meter shows what is left by default: R$20 cap - R$5 spent.
        XCTAssertEqual(data.valueText, "R$15.00")
        XCTAssertEqual(data.menuBarValue, "R$15")
        XCTAssertEqual(data.boundedSubtitle, "R$20 limit")
    }

    func testUncappedBRLSpendRendersRealSign() async {
        let data = await resolved(line: .values(
            label: "Extra usage spent", values: [MetricValue(number: 1234.56, kind: .dollars, currency: "BRL")]
        ))
        XCTAssertEqual(data.unboundedDetail, "R$1.2K spent")
        XCTAssertEqual(data.menuBarValue, "R$1.2K")
        XCTAssertEqual(data.unboundedTooltip, "R$1,234.56")
    }

    // MARK: - Claude mapper

    func testClaudeBRLExtraUsageCarriesCurrency() throws {
        let lines = try claudeLines(#""currency":"BRL","decimal_places":2,"used_credits":500,"monthly_limit":2000"#)
        XCTAssertEqual(
            lines.first { $0.label == "Extra usage spent" },
            .progress(label: "Extra usage spent", used: 5, limit: 20, format: .dollars(currency: "BRL"))
        )
    }

    func testClaudeUncappedBRLExtraUsageCarriesCurrency() throws {
        let lines = try claudeLines(#""currency":"brl","used_credits":123456"#)
        XCTAssertEqual(
            lines.first { $0.label == "Extra usage spent" },
            .values(label: "Extra usage spent", values: [MetricValue(number: 1234.56, kind: .dollars, currency: "BRL")])
        )
    }

    func testClaudeUSDExtraUsageStaysUSD() throws {
        let lines = try claudeLines(#""currency":"USD","used_credits":500,"monthly_limit":1000"#)
        XCTAssertEqual(
            lines.first { $0.label == "Extra usage spent" },
            .progress(label: "Extra usage spent", used: 5, limit: 10, format: .dollars(currency: "USD"))
        )
    }

    func testClaudeExtraUsageWithoutOrEmptyCurrencyIsUSD() throws {
        for fields in [#""used_credits":500,"monthly_limit":1000"#, #""currency":" ","used_credits":500,"monthly_limit":1000"#] {
            let lines = try claudeLines(fields)
            XCTAssertEqual(
                lines.first { $0.label == "Extra usage spent" },
                .progress(label: "Extra usage spent", used: 5, limit: 10, format: .dollars()),
                fields
            )
        }
    }

    func testClaudeExtraUsageHonorsDecimalPlaces() throws {
        let lines = try claudeLines(#""currency":"JPY","decimal_places":0,"used_credits":500,"monthly_limit":1000"#)
        XCTAssertEqual(
            lines.first { $0.label == "Extra usage spent" },
            .progress(label: "Extra usage spent", used: 500, limit: 1000, format: .dollars(currency: "JPY"))
        )
    }

    // MARK: - Limits API

    func testClaudeExtraUsageUnitIsTheRealCurrency() throws {
        let progress = try extraUsageResource(.progress(
            label: "Extra usage spent", used: 5, limit: 20, format: .dollars(currency: "BRL")
        ))
        XCTAssertEqual(progress["unit"] as? String, "brl")

        let uncapped = try extraUsageResource(.values(
            label: "Extra usage spent", values: [MetricValue(number: 12.5, kind: .dollars, currency: "BRL")]
        ))
        XCTAssertEqual(uncapped["unit"] as? String, "brl")
    }

    func testMoneyWithoutCurrencyStillReportsUSD() throws {
        let progress = try extraUsageResource(.progress(label: "Extra usage spent", used: 5, limit: 20, format: .dollars()))
        XCTAssertEqual(progress["unit"] as? String, "usd")

        let uncapped = try extraUsageResource(.values(
            label: "Extra usage spent", values: [MetricValue(number: 12.5, kind: .dollars)]
        ))
        XCTAssertEqual(uncapped["unit"] as? String, "usd")
    }

    // MARK: - Helpers

    private let provider = Provider(id: "claude", displayName: "Claude", icon: .providerMark("claude"))

    private var extraDescriptor: WidgetDescriptor {
        WidgetDescriptor.boundedDollars(
            id: "claude.extra", provider: provider, title: "Extra Usage",
            metricLabel: "Extra usage spent", limit: 100, valueWord: "spent"
        ).exportingLimit("extraUsage", unit: "usd", source: .progressOrValue(kind: .dollars))
    }

    private func claudeLines(_ extraUsageFields: String) throws -> [MetricLine] {
        let body = #"{"extra_usage":{"is_enabled":true,"# + extraUsageFields + "}}"
        let response = HTTPResponse(statusCode: 200, headers: [:], body: Data(body.utf8))
        return try ClaudeUsageMapper.mapUsageResponse(response, credentials: ClaudeOAuth(subscriptionType: "max")).lines
    }

    private func resolved(line: MetricLine) async -> WidgetData {
        let descriptor = extraDescriptor
        let runtime = TestProviderRuntime(
            provider: provider,
            descriptors: [descriptor],
            snapshot: ProviderSnapshot(providerID: provider.id, displayName: provider.displayName, lines: [line])
        )
        let suiteName = "OpenUsageTests.money-currency.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let store = WidgetDataStore(
            registry: WidgetRegistry(providers: [provider], descriptors: [descriptor]),
            providers: [runtime],
            cache: ProviderSnapshotCache(userDefaults: defaults, storageKey: "snapshots", ttl: 600, now: { Date() }),
            defaults: defaults
        )
        await store.refreshAll()
        return store.data(for: descriptor)
    }

    private func extraUsageResource(_ line: MetricLine) throws -> [String: Any] {
        let snapshot = ProviderSnapshot(providerID: "claude", displayName: "Claude", lines: [line])
        let state = LocalUsageAPI.State(
            enabledOrderedIDs: ["claude"],
            knownIDs: ["claude"],
            snapshots: ["claude": snapshot],
            limitDescriptors: ["claude": [extraDescriptor]],
            generatedAt: Date()
        )
        let body = try XCTUnwrap(LocalUsageAPI.respond(method: "GET", path: "/v1/limits", state: state).body)
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        let claude = try XCTUnwrap((root["providers"] as? [String: Any])?["claude"] as? [String: Any])
        return try XCTUnwrap((claude["resources"] as? [String: Any])?["extraUsage"] as? [String: Any])
    }
}
