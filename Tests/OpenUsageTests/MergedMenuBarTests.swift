import XCTest
@testable import OpenUsage

/// The menu bar shows one item per provider family: two enabled accounts fold into one item that
/// carries the family's base pins and the merged (average) value.
@MainActor
final class MergedMenuBarTests: XCTestCase {
    private let work = Provider(id: "claude", displayName: "Claude: work@example.com", icon: .providerMark("claude"))
    private let home = Provider(id: "claude@ab12cd34", displayName: "Claude: home@example.com", icon: .providerMark("claude"))
    private let cursor = Provider(id: "cursor", displayName: "Cursor", icon: .providerMark("cursor"))

    private func descriptors(_ provider: Provider) -> [WidgetDescriptor] {
        ["Session", "Weekly"].map { label in
            WidgetDescriptor(id: "\(provider.id).\(label.lowercased())", providerID: provider.id, metricLabel: label,
                             sample: WidgetData(title: label, icon: provider.icon, kind: .percent, used: 0, limit: 100))
        }
    }

    private func registry(_ providers: [Provider]) -> WidgetRegistry {
        WidgetRegistry(providers: providers, descriptors: providers.flatMap(descriptors))
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "OpenUsageTests.MergedMenuBar.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        addTeardownBlock { defaults.removePersistentDomain(forName: suiteName) }
        return defaults
    }

    private func layout(_ providers: [Provider], pinned: [String], disabled: Set<String> = []) -> LayoutStore {
        let base = ["claude.session", "claude.weekly", "cursor.session", "cursor.weekly"]
        return LayoutStore(
            registry: registry(providers),
            defaults: makeDefaults(),
            defaultMetricIDs: DefaultLayout.expandingAccounts(base, providerIDs: providers.map(\.id)),
            defaultPinnedMetricIDs: pinned,
            defaultExpandedMetricIDs: [],
            isProviderEnabled: { !disabled.contains($0) }
        )
    }

    /// A data store whose accounts report the given Weekly (and optional Session) percentages.
    private func dataStore(_ weekly: [(Provider, Double)], session: [String: Double] = [:]) async -> WidgetDataStore {
        let providers = weekly.map(\.0)
        let runtimes = weekly.map { provider, used in
            var lines: [MetricLine] = [.progress(label: "Weekly", used: used, limit: 100, format: .percent,
                                                 resetsAt: nil, periodDurationMs: nil)]
            if let sessionUsed = session[provider.id] {
                lines.append(.progress(label: "Session", used: sessionUsed, limit: 100, format: .percent,
                                       resetsAt: nil, periodDurationMs: nil))
            }
            return TestProviderRuntime(
                provider: provider,
                descriptors: descriptors(provider),
                snapshot: ProviderSnapshot(providerID: provider.id, displayName: provider.displayName, lines: lines)
            )
        }
        let store = WidgetDataStore(registry: registry(providers), providers: runtimes, defaults: makeDefaults())
        await store.refreshAll()
        return store
    }

    func testTwoAccountsPinAsOneFamilyItemFromTheBaseMetricIDs() {
        // The other account's own pin must not add a second Claude item.
        let store = layout([work, home, cursor], pinned: ["claude.weekly", "claude@ab12cd34.session", "cursor.weekly"])
        let groups = store.pinnedGroups

        XCTAssertEqual(groups.map(\.provider.id), ["claude", "cursor"])
        XCTAssertEqual(groups[0].provider.displayName, "Claude")
        XCTAssertEqual(groups[0].metrics.map(\.id), ["claude.weekly"])
        XCTAssertEqual(groups[0].accounts.map(\.providerID), ["claude", "claude@ab12cd34"])
        XCTAssertTrue(groups[1].accounts.isEmpty)
    }

    func testTwoAccountsShowTheMergedValueInOneItem() async {
        let data = await dataStore([(work, 20), (home, 60)])
        let store = layout([work, home], pinned: ["claude.weekly"])

        let content = MenuBarContentBuilder.build(groups: store.pinnedGroups, data: data.data(for:in:))

        XCTAssertEqual(content.groups.map(\.providerID), ["claude"])
        XCTAssertEqual(content.groups[0].displayName, "Claude")
        XCTAssertEqual(content.groups[0].icon, .providerMark("claude"))
        XCTAssertEqual(content.groups[0].metrics.map(\.id), ["claude.weekly"])
        XCTAssertEqual(content.groups[0].metrics[0].usedFraction, 0.4, accuracy: 0.0001)
        XCTAssertEqual(content.groups[0].metrics[0].value, "60%", "the default meter style shows what is left")
    }

    func testTwoBasePinsStackTheirMergedValuesInOneItem() async {
        let data = await dataStore([(work, 20), (home, 60)], session: ["claude": 10, "claude@ab12cd34": 50])
        let store = layout([work, home], pinned: ["claude.session", "claude.weekly",
                                                  "claude@ab12cd34.session", "claude@ab12cd34.weekly"])

        let content = MenuBarContentBuilder.build(groups: store.pinnedGroups, data: data.data(for:in:))

        XCTAssertEqual(content.groups.map(\.providerID), ["claude"])
        XCTAssertEqual(content.groups[0].metrics.map(\.id), ["claude.session", "claude.weekly"])
        XCTAssertEqual(content.groups[0].metrics[0].usedFraction, 0.3, accuracy: 0.0001)
        XCTAssertEqual(content.groups[0].metrics[1].usedFraction, 0.4, accuracy: 0.0001)
    }

    func testSingleAccountFamilyIsUnchanged() async {
        let data = await dataStore([(work, 20), (home, 60)])
        let store = layout([work, home], pinned: ["claude.weekly", "claude@ab12cd34.weekly"], disabled: ["claude"])
        let groups = store.pinnedGroups

        XCTAssertEqual(groups.map(\.provider), [home])
        XCTAssertTrue(groups[0].accounts.isEmpty)
        let content = MenuBarContentBuilder.build(groups: groups, data: data.data(for:in:))
        XCTAssertEqual(content.groups.map(\.displayName), [home.displayName])
        XCTAssertEqual(content.groups[0].metrics.map(\.id), ["claude@ab12cd34.weekly"])
        XCTAssertEqual(content.groups[0].metrics[0].usedFraction, 0.6, accuracy: 0.0001)
    }
}
