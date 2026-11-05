import XCTest
@testable import OpenUsage

@MainActor
final class MergedProviderGroupTests: XCTestCase {
    private let work = Provider(id: "claude", displayName: "Claude: work@example.com", icon: .providerMark("claude"))
    private let home = Provider(id: "claude@ab12cd34", displayName: "Claude: home@example.com (Hub lab)", icon: .providerMark("claude"))
    private let spare = Provider(id: "claude@ffff0000", displayName: "Claude — Spare Org", icon: .providerMark("claude"))
    private let cursor = Provider(id: "cursor", displayName: "Cursor", icon: .providerMark("cursor"))

    private func descriptors(_ provider: Provider) -> [WidgetDescriptor] {
        [
            WidgetDescriptor(id: "\(provider.id).session", providerID: provider.id, metricLabel: "Session",
                             sample: WidgetData(title: "Session", icon: provider.icon, kind: .percent, used: 0, limit: 100)),
            WidgetDescriptor(id: "\(provider.id).weekly", providerID: provider.id, metricLabel: "Weekly",
                             sample: WidgetData(title: "Weekly", icon: provider.icon, kind: .percent, used: 0, limit: 100))
        ]
    }

    private func registry(_ providers: [Provider]) -> WidgetRegistry {
        WidgetRegistry(providers: providers, descriptors: providers.flatMap(descriptors))
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "OpenUsageTests.MergedProviderGroup.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        addTeardownBlock { defaults.removePersistentDomain(forName: suiteName) }
        return defaults
    }

    private func layout(_ providers: [Provider], disabled: Set<String> = [],
                        expanded: [String] = []) -> LayoutStore {
        let ids = providers.map(\.id)
        let base = ["claude.session", "claude.weekly", "cursor.session", "cursor.weekly"]
        return LayoutStore(
            registry: registry(providers),
            defaults: makeDefaults(),
            defaultMetricIDs: DefaultLayout.expandingAccounts(base, providerIDs: ids),
            defaultPinnedMetricIDs: [],
            defaultExpandedMetricIDs: expanded,
            isProviderEnabled: { !disabled.contains($0) }
        )
    }

    private func metricIDs(_ group: ProviderGroup?, in store: LayoutStore) -> [String]? {
        group?.widgets.compactMap { store.descriptor(for: $0)?.id }
    }

    func testALoneHubAccountShowsLikeAMergedCard() {
        let hub = Provider(id: "claude@ab12cd34", displayName: "Claude: eu@example.com (Hub lab)",
                           icon: .providerMark("claude"), showsAsFamily: true)
        let group = layout([hub]).displayGroups.first

        XCTAssertEqual(group?.provider.displayName, "Claude")
        XCTAssertEqual(group?.accounts.map(\.shortName), ["eu"])
    }

    func testALoneLocalAccountKeepsItsOrdinaryCard() {
        let group = layout([work]).displayGroups.first

        XCTAssertEqual(group?.provider.displayName, "Claude: work@example.com")
        XCTAssertEqual(group?.accounts, [])
    }

    func testTwoAccountsOfAFamilyShowAsOneCard() {
        let store = layout([work, home, cursor])
        let groups = store.displayGroups

        XCTAssertEqual(groups.map(\.provider.id), ["claude", "cursor"])
        let claude = groups[0]
        XCTAssertEqual(claude.provider.displayName, "Claude")
        XCTAssertEqual(claude.accounts, [
            MergedAccount(providerID: "claude", shortName: "work", colorIndex: 0),
            MergedAccount(providerID: "claude@ab12cd34", shortName: "home", colorIndex: 1)
        ])
        XCTAssertEqual(claude.memberIDs, ["claude", "claude@ab12cd34"])
        XCTAssertEqual(metricIDs(claude, in: store), ["claude.session", "claude.weekly"])
        XCTAssertTrue(groups[1].accounts.isEmpty)
    }

    func testSingleAccountFamilyRendersAsBefore() {
        let store = layout([work, home, cursor], disabled: ["claude@ab12cd34"])
        let claude = store.displayGroups.first { $0.provider.id == "claude" }

        XCTAssertEqual(claude?.provider, work)
        XCTAssertEqual(claude?.accounts, [])
        XCTAssertEqual(claude?.memberIDs, ["claude"])
        XCTAssertEqual(metricIDs(claude, in: store), ["claude.session", "claude.weekly"])
        XCTAssertFalse(store.displayGroups.contains { $0.provider.id == "claude@ab12cd34" })
    }

    func testBaseMetricIDsDriveTheMergedCard() {
        let store = layout([work, home, cursor])
        store.setMetricEnabled("claude.session", false)
        XCTAssertTrue(store.isMetricEnabled("claude@ab12cd34.session"))

        XCTAssertEqual(metricIDs(store.displayGroups.first, in: store), ["claude.weekly"])
    }

    func testDisabledBaseAccountLeavesTheMergeButKeepsItsLayout() {
        let store = layout([work, home, spare, cursor], disabled: ["claude"])
        let claude = store.displayGroups.first

        XCTAssertEqual(claude?.provider.id, "claude")
        XCTAssertEqual(claude?.accounts.map(\.providerID), ["claude@ab12cd34", "claude@ffff0000"])
        XCTAssertEqual(claude?.accounts.map(\.shortName), ["home", "Spare Org"])
        XCTAssertEqual(metricIDs(claude, in: store), ["claude.session", "claude.weekly"])
    }

    func testCollidingLegendNamesKeepTheirDetail() {
        let alice = Provider(id: "claude", displayName: "Claude: Acme Org (alice@x.com)", icon: .providerMark("claude"))
        let bob = Provider(id: "claude@ab12cd34", displayName: "Claude: Acme Org (bob@x.com)", icon: .providerMark("claude"))
        let store = layout([alice, bob, spare, cursor])

        XCTAssertEqual(store.displayGroups.first?.accounts.map(\.shortName),
                       ["Acme Org (alice)", "Acme Org (bob)", "Spare Org"])
    }

    func testMergedCardFollowsTheBaseAccountsPosition() {
        let store = layout([work, home, cursor])
        XCTAssertTrue(store.reorderProvider(dragged: "cursor", target: "claude"))
        XCTAssertEqual(store.displayGroups.map(\.provider.id), ["cursor", "claude"])
    }

    func testMergedCardClaimsNoResetCredit() {
        // A merged resets popover lists every account's credits, so no one account's claim service may
        // take a click on them.
        let merged = layout([work, home, cursor]).displayGroups
        XCTAssertNil(merged.first { $0.provider.id == "claude" }?.resetClaimProviderID)
        XCTAssertEqual(merged.first { $0.provider.id == "cursor" }?.resetClaimProviderID, "cursor")

        let single = layout([work, home], disabled: ["claude@ab12cd34"]).displayGroups
        XCTAssertEqual(single.first?.resetClaimProviderID, "claude")
    }

    func testDataStoreMergesEachAccountsReading() async throws {
        let providers = [work, home]
        let registry = registry(providers)
        let runtimes = zip(providers, [20.0, 60.0]).map { provider, weekly in
            TestProviderRuntime(
                provider: provider,
                descriptors: descriptors(provider),
                snapshot: ProviderSnapshot(
                    providerID: provider.id,
                    displayName: provider.displayName,
                    lines: [.progress(label: "Weekly", used: weekly, limit: 100, format: .percent,
                                      resetsAt: nil, periodDurationMs: nil)]
                )
            )
        }
        let dataStore = WidgetDataStore(registry: registry, providers: runtimes, defaults: makeDefaults())
        await dataStore.refreshAll()
        let store = layout(providers)
        let group = try XCTUnwrap(store.displayGroups.first)
        let weekly = try XCTUnwrap(registry.descriptor(id: "claude.weekly"))

        let data = dataStore.data(for: weekly, in: group)

        XCTAssertEqual(data.used, 40)
        XCTAssertEqual(data.accountTicks.map(\.used), [20, 60])
        let session = try XCTUnwrap(registry.descriptor(id: "claude.session"))
        XCTAssertFalse(dataStore.data(for: session, in: group).hasData, "no account reports a session line")
    }

    func testAccountWithoutTheMetricsDescriptorIsLeftOutOfTheMerge() async throws {
        // `home` reports a Session line but registers no `home.session` descriptor.
        let homeWeeklyOnly = descriptors(home).filter { $0.id.hasSuffix(".weekly") }
        let registry = WidgetRegistry(providers: [work, home], descriptors: descriptors(work) + homeWeeklyOnly)
        let lines: [MetricLine] = [.progress(label: "Session", used: 30, limit: 100, format: .percent,
                                             resetsAt: nil, periodDurationMs: nil)]
        let runtimes = [
            TestProviderRuntime(provider: work, descriptors: descriptors(work),
                                snapshot: ProviderSnapshot(providerID: work.id, displayName: work.displayName, lines: lines)),
            TestProviderRuntime(provider: home, descriptors: homeWeeklyOnly,
                                snapshot: ProviderSnapshot(providerID: home.id, displayName: home.displayName, lines: lines))
        ]
        let dataStore = WidgetDataStore(registry: registry, providers: runtimes, defaults: makeDefaults())
        await dataStore.refreshAll()
        let accounts = [
            MergedAccount(providerID: work.id, shortName: "work", colorIndex: 0),
            MergedAccount(providerID: home.id, shortName: "home", colorIndex: 1)
        ]
        let group = ProviderGroup(provider: work, alwaysShownWidgets: [], expandedWidgets: [], accounts: accounts)

        let data = dataStore.data(for: try XCTUnwrap(registry.descriptor(id: "claude.session")), in: group)

        XCTAssertEqual(data.used, 30)
        XCTAssertEqual(data.accountTicks.map(\.account.providerID), ["claude"])
    }

    func testReorderingAMergedCardMovesTheBaseMetrics() {
        // The base account is off, so the card's order can only come from its metric ids.
        let store = layout([work, home, spare], disabled: ["claude"])
        XCTAssertTrue(store.reorderMetric(dragged: "claude.weekly", target: "claude.session", in: "claude"))

        XCTAssertEqual(metricIDs(store.displayGroups.first, in: store), ["claude.weekly", "claude.session"])
    }

    func testOnDemandSplitFollowsTheBaseMetrics() {
        let store = layout([work, home, spare], disabled: ["claude"], expanded: ["claude.weekly"])
        let claude = store.displayGroups.first

        XCTAssertEqual(claude?.alwaysShownWidgets.compactMap { store.descriptor(for: $0)?.id }, ["claude.session"])
        XCTAssertEqual(claude?.expandedWidgets.compactMap { store.descriptor(for: $0)?.id }, ["claude.weekly"])
    }
}
