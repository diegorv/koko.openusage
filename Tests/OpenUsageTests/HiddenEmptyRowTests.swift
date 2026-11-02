import XCTest
@testable import OpenUsage

/// Claude's Session row hides while Anthropic reports no five-hour window (`five_hour: null`) and comes
/// back by itself once a reading arrives. Other metrics keep their "No data" row.
@MainActor
final class HiddenEmptyRowTests: XCTestCase {
    private let work = ClaudeProvider.makeProvider()
    private let home = ClaudeProvider.makeProvider(id: "claude@ab12cd34", displayName: "Claude: home@example.com")

    private func descriptors(_ provider: Provider) -> [WidgetDescriptor] {
        ClaudeProvider.limitDescriptors(provider: provider)
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "OpenUsageTests.HiddenEmptyRow.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        addTeardownBlock { defaults.removePersistentDomain(forName: suiteName) }
        return defaults
    }

    private func layout(_ providers: [Provider], expanded: [String] = [], pinned: [String] = []) -> LayoutStore {
        LayoutStore(
            registry: WidgetRegistry(providers: providers, descriptors: providers.flatMap(descriptors)),
            defaults: makeDefaults(),
            defaultMetricIDs: DefaultLayout.expandingAccounts(["claude.session", "claude.weekly"],
                                                              providerIDs: providers.map(\.id)),
            defaultPinnedMetricIDs: pinned,
            defaultExpandedMetricIDs: expanded,
            isProviderEnabled: { _ in true }
        )
    }

    /// Lines the real Claude mapper produces for a `/api/oauth/usage` body.
    private func claudeLines(_ body: String) throws -> [MetricLine] {
        let response = HTTPResponse(statusCode: 200, headers: [:], body: Data(body.utf8))
        return try ClaudeUsageMapper.mapUsageResponse(response, credentials: ClaudeOAuth(subscriptionType: "max")).lines
    }

    private let noFiveHour = #"{"five_hour":null,"seven_day":{"utilization":30,"resets_at":"2099-01-01T00:00:00.000Z"}}"#
    private let withFiveHour = #"{"five_hour":{"utilization":10,"resets_at":"2099-01-01T00:00:00.000Z"},"seven_day":{"utilization":30,"resets_at":"2099-01-01T00:00:00.000Z"}}"#

    private func dataStore(_ lines: [(Provider, [MetricLine])]) async -> WidgetDataStore {
        let providers = lines.map(\.0)
        let runtimes = lines.map { provider, lines in
            TestProviderRuntime(
                provider: provider,
                descriptors: descriptors(provider),
                snapshot: ProviderSnapshot(providerID: provider.id, displayName: provider.displayName, lines: lines)
            )
        }
        let store = WidgetDataStore(
            registry: WidgetRegistry(providers: providers, descriptors: providers.flatMap(descriptors)),
            providers: runtimes,
            defaults: makeDefaults()
        )
        await store.refreshAll()
        return store
    }

    private func shownIDs(_ data: WidgetDataStore, _ store: LayoutStore)
        -> (always: [String], expanded: [String]) {
        let group = data.shownGroup(store.displayGroups[0], descriptor: store.descriptor(for:))
        return (group.alwaysShownWidgets.compactMap { store.descriptor(for: $0)?.id },
                group.expandedWidgets.compactMap { store.descriptor(for: $0)?.id })
    }

    func testClaudeSessionOptsInForEveryAccountAndNothingElseDoes() {
        for provider in [work, home] {
            let optedIn = descriptors(provider).filter(\.hidesWithoutData).map(\.id)
            XCTAssertEqual(optedIn, ["\(provider.id).session"])
        }
    }

    func testSessionHidesWhenAnthropicReportsNoFiveHourWindow() async throws {
        let data = await dataStore([(work, try claudeLines(noFiveHour))])

        XCTAssertEqual(shownIDs(data, layout([work])).always, ["claude.weekly"])
    }

    func testSessionShowsWhenTheFiveHourWindowIsReported() async throws {
        let data = await dataStore([(work, try claudeLines(withFiveHour))])

        XCTAssertEqual(shownIDs(data, layout([work])).always, ["claude.session", "claude.weekly"])
    }

    func testMergedCardShowsSessionWhenOneAccountHasIt() async throws {
        let data = await dataStore([(work, try claudeLines(noFiveHour)), (home, try claudeLines(withFiveHour))])
        let store = layout([work, home])

        XCTAssertEqual(store.displayGroups[0].accounts.count, 2)
        XCTAssertEqual(shownIDs(data, store).always, ["claude.session", "claude.weekly"])
    }

    func testMergedCardHidesSessionWhenNoAccountHasIt() async throws {
        let data = await dataStore([(work, try claudeLines(noFiveHour)), (home, try claudeLines(noFiveHour))])

        XCTAssertEqual(shownIDs(data, layout([work, home])).always, ["claude.weekly"])
    }

    func testOtherMetricWithoutDataStillShowsNoData() async throws {
        let data = await dataStore([(work, [])])
        let store = layout([work])

        // Session hides; Weekly does not opt in, so it stays and reads "No data".
        XCTAssertEqual(shownIDs(data, store).always, ["claude.weekly"])
        let weekly = try XCTUnwrap(store.registry.descriptor(id: "claude.weekly"))
        XCTAssertFalse(data.data(for: weekly).hasData)
    }

    func testHiddenAlwaysVisibleRowPromotesTheOnDemandRows() async throws {
        let data = await dataStore([(work, try claudeLines(noFiveHour))])
        let store = layout([work], expanded: ["claude.weekly"])

        let shown = shownIDs(data, store)
        XCTAssertEqual(shown.always, ["claude.weekly"])
        XCTAssertEqual(shown.expanded, [])
    }

    func testOnlyRowStaysInsteadOfAnEmptyCard() async throws {
        let data = await dataStore([(work, try claudeLines(noFiveHour))])
        let store = layout([work])
        store.setMetricEnabled("claude.weekly", false)

        XCTAssertEqual(shownIDs(data, store).always, ["claude.session"])
    }

    func testMenuBarSkipsPinnedSessionWithoutData() async throws {
        let data = await dataStore([(work, try claudeLines(noFiveHour))])
        let store = layout([work], pinned: ["claude.session", "claude.weekly"])

        let content = MenuBarContentBuilder.build(groups: store.pinnedGroups, data: data.data(for:in:))

        XCTAssertEqual(content.groups.map(\.providerID), ["claude"])
        XCTAssertEqual(content.groups[0].metrics.map(\.id), ["claude.weekly"])
    }
}
