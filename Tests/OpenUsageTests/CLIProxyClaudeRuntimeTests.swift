import os
import XCTest
@testable import OpenUsage

@MainActor
final class CLIProxyClaudeRuntimeTests: XCTestCase {
    nonisolated private static let usageBody = """
    {
      "five_hour": { "utilization": 10, "resets_at": "2099-01-01T00:00:00.000Z" },
      "seven_day": { "utilization": 20, "resets_at": "2099-01-01T00:00:00.000Z" },
      "seven_day_sonnet": { "utilization": 5, "resets_at": "2099-01-01T00:00:00.000Z" },
      "extra_usage": { "is_enabled": true, "used_credits": 500, "monthly_limit": 1000 }
    }
    """

    nonisolated private static func hub(
        id: String = "cliproxy-hub-example",
        label: String? = "Home",
        accounts: [CLIProxyHubAccount]
    ) -> CLIProxyHubConfig.Hub {
        CLIProxyHubConfig.Hub(
            id: id, label: label, url: "https://hub.example.ts.net", managementKey: "key", enabled: true,
            accounts: accounts
        )
    }

    nonisolated private static func claude(_ id: String, email: String? = nil) -> CLIProxyHubAccount {
        CLIProxyHubAccount(id: id, authIndex: "idx-\(id)", provider: .claude, email: email)
    }

    nonisolated private static func envelope(status: Int = 200, body: String) -> HTTPResponse {
        let object: [String: Any] = ["status_code": status, "header": [:] as [String: Any], "body": body]
        return HTTPResponse(statusCode: 200, headers: [:], body: try! JSONSerialization.data(withJSONObject: object))
    }

    /// The `api-call` payload the hub received: `auth_index` and the upstream `url`.
    nonisolated private static func payload(_ request: HTTPRequest) -> [String: Any] {
        (request.body.flatMap { try? JSONSerialization.jsonObject(with: $0) } as? [String: Any]) ?? [:]
    }

    private func firstCard(hubs: [CLIProxyHubConfig.Hub], http: any HTTPClient) throws -> CLIProxyClaudeRuntime {
        let runtimes = CLIProxyHubCards.runtimes(hubs: hubs, http: http).claude
        return try XCTUnwrap(runtimes.first)
    }

    private func refreshAll(_ runtimes: [CLIProxyClaudeRuntime]) async -> [ProviderSnapshot] {
        let tasks = runtimes.map { runtime in Task { await runtime.refresh() } }
        var snapshots: [ProviderSnapshot] = []
        for task in tasks { snapshots.append(await task.value) }
        return snapshots
    }

    private func errorText(_ snapshot: ProviderSnapshot) -> String? {
        for case .badge(let label, let text, _, _) in snapshot.lines where label == MetricLine.errorBadgeLabel {
            return text
        }
        return nil
    }

    func testDashboardLinkOpensTheConfiguredHub() throws {
        for url in ["https://hub.example.ts.net:8317", "https://hub.example.ts.net:8317/"] {
            let hub = CLIProxyHubConfig.Hub(
                id: "h", label: nil, url: url, managementKey: "key", enabled: true,
                accounts: [
                    Self.claude("claude-a.json"),
                    CLIProxyHubAccount(id: "codex-a.json", authIndex: "i", provider: .codex)
                ]
            )
            let cards = CLIProxyHubCards.runtimes(hubs: [hub], http: RoutingHTTPClient { _ in Self.envelope(body: "") })

            for provider in [cards.claude[0].provider, cards.codex[0].provider] {
                XCTAssertEqual(provider.links.first { $0.label == "Dashboard" }?.url,
                               "https://hub.example.ts.net:8317/management.html#/auth-files")
                XCTAssertEqual(provider.links.count, 2, "Status stays")
            }
        }
    }

    // MARK: - Limits

    private nonisolated static let profileBody = #"{"account":{"uuid":"a"},"organization":{"uuid":"o","organization_type":"claude_max","rate_limit_tier":"default_claude_max_20x"}}"#

    private nonisolated static func isProfileCall(_ request: HTTPRequest) -> Bool {
        (payload(request)["url"] as? String)?.hasSuffix("/api/oauth/profile") == true
    }

    func testShowsThePlanFromTheProfileReadThroughTheHub() async throws {
        let http = RoutingHTTPClient { request in
            Self.envelope(body: Self.isProfileCall(request) ? Self.profileBody : Self.usageBody)
        }
        let runtime = try firstCard(hubs: [Self.hub(accounts: [Self.claude("claude-a.json")])], http: http)

        let snapshot = await runtime.refresh()

        XCTAssertEqual(snapshot.plan, "Max 20x")
        XCTAssertNil(errorText(snapshot))
    }

    func testAKnownPlanIsNotFetchedAgain() async throws {
        let http = RoutingHTTPClient { request in
            Self.envelope(body: Self.isProfileCall(request) ? Self.profileBody : Self.usageBody)
        }
        let runtime = try firstCard(hubs: [Self.hub(accounts: [Self.claude("claude-a.json")])], http: http)

        _ = await runtime.refresh()
        let second = await runtime.refresh()

        XCTAssertEqual(second.plan, "Max 20x")
        XCTAssertEqual(http.requests.filter(Self.isProfileCall).count, 1)
    }

    func testAFailedPlanLookupKeepsTheLimitsAndRetriesNextRefresh() async throws {
        let http = RoutingHTTPClient { request in
            Self.isProfileCall(request) ? Self.envelope(status: 503, body: "") : Self.envelope(body: Self.usageBody)
        }
        let runtime = try firstCard(hubs: [Self.hub(accounts: [Self.claude("claude-a.json")])], http: http)

        let first = await runtime.refresh()
        _ = await runtime.refresh()

        XCTAssertNil(first.plan)
        XCTAssertNil(errorText(first))
        XCTAssertEqual(http.requests.filter(Self.isProfileCall).count, 2)
    }

    func testMapsTheAccountsLimitsThroughTheHub() async throws {
        let http = RoutingHTTPClient { _ in Self.envelope(body: Self.usageBody) }
        let runtime = try firstCard(
            hubs: [Self.hub(accounts: [Self.claude("claude-a.json", email: "a@example.com")])], http: http
        )

        let snapshot = await runtime.refresh()

        XCTAssertNil(errorText(snapshot))
        XCTAssertEqual(snapshot.lines.map(\.label), ["Session", "Weekly", "Sonnet", "Extra usage spent"])
        let payload = Self.payload(try XCTUnwrap(http.requests.first))
        XCTAssertEqual(payload["auth_index"] as? String, "idx-claude-a.json")
        XCTAssertEqual(payload["url"] as? String, "https://api.anthropic.com/api/oauth/usage")
    }

    func testShowsLimitsOnlyWithTheClaudeMetricIDs() throws {
        let runtime = try firstCard(
            hubs: [Self.hub(accounts: [Self.claude("claude-a.json")])], http: RoutingHTTPClient { _ in Self.envelope(body: "{}") }
        )
        let id = runtime.provider.id

        XCTAssertEqual(runtime.widgetDescriptors.map(\.id), [
            "\(id).session", "\(id).weekly", "\(id).fable", "\(id).sonnet", "\(id).extra"
        ])
        XCTAssertFalse(runtime.widgetDescriptors.contains { $0.isSpendTile || $0.historyResource != nil })
        // Same suffixes as the local Claude card, so `DefaultLayout.expandingAccounts` gives hub cards
        // the Claude family's defaults.
        let local = Set(ClaudeProvider().widgetDescriptors.map(\.id))
        XCTAssertTrue(runtime.widgetDescriptors.allSatisfy { local.contains("claude" + $0.id.dropFirst(id.count)) })
    }

    func testUpstreamUnauthorizedAsksForAHubReloginWithoutRefreshingOrWriting() async throws {
        let files = FakeFiles()
        let store = CLIProxyHubConfigStore(files: files)
        try store.save(CLIProxyHubConfig(hubs: [Self.hub(accounts: [Self.claude("claude-a.json")])]))
        let before = files.files
        let http = RoutingHTTPClient { _ in Self.envelope(status: 401, body: #"{"error":"invalid_token"}"#) }
        let runtime = try firstCard(hubs: try store.load().hubs, http: http)

        let snapshot = await runtime.refresh()

        XCTAssertEqual(errorText(snapshot), CLIProxyHubAccountError.reloginRequired.localizedDescription)
        XCTAssertTrue(errorText(snapshot)?.contains("Re-login this account on the hub") == true)
        XCTAssertEqual(snapshot.errorCategory, .authExpired)
        XCTAssertEqual(http.requests.count, 1, "no token refresh and no retry")
        XCTAssertEqual(Self.payload(http.requests[0])["url"] as? String, "https://api.anthropic.com/api/oauth/usage")
        XCTAssertEqual(files.files, before)
    }

    func testRateLimitKeepsTheLastGoodLimitsWithANote() async throws {
        let status = OSAllocatedUnfairLock(initialState: 200)
        let http = RoutingHTTPClient { _ in
            status.withLock { $0 } == 200
                ? Self.envelope(body: Self.usageBody)
                : Self.envelope(status: 429, body: #"{"error":"rate_limited"}"#)
        }
        let runtime = try firstCard(
            hubs: [Self.hub(accounts: [Self.claude("claude-a.json")])], http: http
        )
        _ = await runtime.refresh()
        status.withLock { $0 = 429 }

        let snapshot = await runtime.refresh()

        XCTAssertNil(errorText(snapshot))
        XCTAssertEqual(snapshot.lines.map(\.label), ["Session", "Weekly", "Sonnet", "Extra usage spent", "Note"])
        XCTAssertNotNil(snapshot.warning)
    }

    func testHubCardsAreNeverLocalCredentials() async throws {
        let runtime = try firstCard(
            hubs: [Self.hub(accounts: [Self.claude("claude-a.json")])], http: RoutingHTTPClient { _ in Self.envelope(body: "{}") }
        )
        let hasCredentials = await runtime.hasLocalCredentials()
        XCTAssertFalse(hasCredentials)
        let detected = await FirstRunSeeder.detectLocalProviders([runtime])
        XCTAssertEqual(detected, [])
    }

    // MARK: - Hub-wide vs per-account failures

    func testHubWideFailureIsSharedByEveryCardOfThatHub() async throws {
        let http = RoutingHTTPClient { _ in throw URLError(.cannotConnectToHost) }
        let accounts = (1...8).map { Self.claude("claude-\($0).json") }
        let runtimes = CLIProxyHubCards.runtimes(hubs: [Self.hub(accounts: accounts)], http: http).claude

        let snapshots = await refreshAll(runtimes)

        XCTAssertEqual(Set(snapshots.map(errorText)), [CLIProxyHubError.unreachable.localizedDescription])
        XCTAssertLessThanOrEqual(http.requests.count, CLIProxyHubSession.maxConcurrentCalls, "the failure is found once per refresh")

        // The next refresh asks the hub again rather than replaying an old failure.
        let before = http.requests.count
        _ = await runtimes[0].refresh()
        XCTAssertEqual(http.requests.count, before + 1)
    }

    func testOneAccountFailingFailsOnlyItsCard() async throws {
        let http = RoutingHTTPClient { request in
            Self.payload(request)["auth_index"] as? String == "idx-bad.json"
                ? Self.envelope(status: 401, body: "{}")
                : Self.envelope(body: Self.usageBody)
        }
        let runtimes = CLIProxyHubCards.runtimes(
            hubs: [Self.hub(accounts: [Self.claude("bad.json"), Self.claude("good.json")])], http: http
        ).claude

        let snapshots = await refreshAll(runtimes)

        XCTAssertEqual(errorText(snapshots[0]), CLIProxyHubAccountError.reloginRequired.localizedDescription)
        XCTAssertNil(errorText(snapshots[1]))
    }

    func testAtMostFourAPICallsRunAtOncePerHub() async throws {
        let counter = OSAllocatedUnfairLock(initialState: (current: 0, peak: 0))
        let http = RoutingHTTPClient { _ in
            counter.withLock { $0.current += 1; $0.peak = max($0.peak, $0.current) }
            try await Task.sleep(nanoseconds: 30_000_000)
            counter.withLock { $0.current -= 1 }
            return Self.envelope(body: Self.usageBody)
        }
        let accounts = (1...10).map { Self.claude("claude-\($0).json") }
        let runtimes = CLIProxyHubCards.runtimes(hubs: [Self.hub(accounts: accounts)], http: http).claude

        let snapshots = await refreshAll(runtimes)

        XCTAssertEqual(snapshots.compactMap(errorText), [])
        XCTAssertEqual(http.requests.filter { !Self.isProfileCall($0) }.count, 10)
        let peak = counter.withLock { $0.peak }
        XCTAssertLessThanOrEqual(peak, CLIProxyHubSession.maxConcurrentCalls)
        XCTAssertGreaterThan(peak, 1, "calls should overlap up to the cap")
    }

    // MARK: - Cards

    func testCardIDsAreStablePerHubAndAccountAndNamedForTheHub() {
        let http = RoutingHTTPClient { _ in Self.envelope(body: "{}") }
        let account = Self.claude("claude-a.json", email: "a@example.com")
        let first = CLIProxyHubCards.runtimes(hubs: [Self.hub(accounts: [account])], http: http).claude
        let again = CLIProxyHubCards.runtimes(hubs: [Self.hub(accounts: [account])], http: http).claude
        let otherHub = CLIProxyHubCards.runtimes(hubs: [Self.hub(id: "other", accounts: [account])], http: http).claude

        XCTAssertEqual(first.map(\.provider.id), again.map(\.provider.id))
        XCTAssertNotEqual(first.map(\.provider.id), otherHub.map(\.provider.id))
        XCTAssertEqual(first.first?.provider.id, ProviderAccountID.make(family: "claude", identityKey: "cliproxy:cliproxy-hub-example:claude-a.json"))
        XCTAssertEqual(ProviderAccountID.family(of: first[0].provider.id), "claude")
        XCTAssertEqual(first.first?.provider.displayName, "Claude: a@example.com (Hub Home)")
    }

    func testOnlyEnabledHubsAndClaudeAccountsBecomeCards() {
        var disabled = Self.hub(id: "off", accounts: [Self.claude("off.json")])
        disabled.enabled = false
        let codex = CLIProxyHubAccount(id: "codex.json", authIndex: "c", provider: .codex)
        let runtimes = CLIProxyHubCards.runtimes(
            hubs: [Self.hub(accounts: [Self.claude("on.json"), codex]), disabled],
            http: RoutingHTTPClient { _ in Self.envelope(body: "{}") }
        ).claude
        XCTAssertEqual(runtimes.map(\.account.id), ["on.json"])
    }

    /// A hand-edited config can repeat a hub or an account, or differ only in case (card ids are
    /// minted from the lowercased key). Duplicate ids would crash the data store at launch.
    func testDuplicateHubsAndAccountsKeepTheFirstCardAndStillBuildTheDataStore() {
        let defaults = makeScratchDefaults("CLIProxyHubDuplicates")
        let hubs = [
            Self.hub(accounts: [Self.claude("a.json"), Self.claude("A.json"), Self.claude("a.json"), Self.claude("b.json")]),
            Self.hub(accounts: [Self.claude("c.json")]),
            Self.hub(id: "CLIPROXY-HUB-EXAMPLE", accounts: [Self.claude("d.json")])
        ]

        let runtimes = CLIProxyHubCards.runtimes(hubs: hubs, http: RoutingHTTPClient { _ in Self.envelope(body: "{}") }).claude

        XCTAssertEqual(runtimes.map(\.account.id), ["a.json", "b.json"])
        let providers = ProviderCatalog.make(defaults: defaults, hubCards: runtimes)
        _ = WidgetDataStore(
            registry: WidgetRegistry.from(providers), providers: providers,
            cache: ProviderSnapshotCache(userDefaults: defaults), defaults: defaults
        )
    }

    /// Hub cards keep no history, so they don't make the local Claude card one of several: its
    /// unowned machine-local history still syncs as before.
    func testHubCardsDoNotDropTheLocalClaudeHistoryFromSync() {
        let defaults = makeScratchDefaults("CLIProxyHubHistory")
        let local = ClaudeProvider.makeProvider(id: "claude", displayName: "Claude")
        let hubCards = CLIProxyHubCards.runtimes(
            hubs: [Self.hub(accounts: [Self.claude("claude-a.json")])], http: RoutingHTTPClient { _ in Self.envelope(body: "{}") }
        ).claude
        let cache = ProviderSnapshotCache(userDefaults: defaults, storageKey: "snapshots")
        let history = ProviderUsageHistory(series: DailyUsageSeries(daily: [
            DailyUsageEntry(date: "2026-07-13", totalTokens: 10, costUSD: 1)
        ]))
        cache.store(ProviderSnapshot(providerID: "claude", displayName: "Claude", lines: [], usageHistory: history))
        let descriptors = [
            WidgetDescriptor.usageTrend(provider: local).exportingHistory(scope: .machineLocal, estimatedCost: true, sourceNote: "logs")
        ] + hubCards.flatMap(\.widgetDescriptors)

        let document = WidgetDataStore(
            registry: WidgetRegistry(providers: [local] + hubCards.map(\.provider), descriptors: descriptors),
            providers: [], cache: cache, defaults: defaults
        ).localHistoryDocument(deviceID: "this-mac", deviceName: "This Mac")

        XCTAssertNotNil(document.providers["claude"])
    }

    func testLaunchWithTheHubUnreachableStillBuildsTheCachedCardsWithoutTheNetwork() async throws {
        let defaults = makeScratchDefaults("CLIProxyHubLaunch")
        let files = FakeFiles()
        try CLIProxyHubConfigStore(files: files).save(CLIProxyHubConfig(hubs: [
            Self.hub(accounts: [Self.claude("claude-a.json", email: "a@example.com"), Self.claude("claude-b.json")])
        ]))
        let http = RoutingHTTPClient { _ in throw URLError(.cannotConnectToHost) }

        let hubCards = await CLIProxyHubCards.loadRuntimes(store: CLIProxyHubConfigStore(files: files), http: http).claude
        let providers = ProviderCatalog.make(defaults: defaults, hubCards: hubCards)
        let registry = WidgetRegistry.from(providers)

        XCTAssertEqual(http.requests.count, 0)
        let ids = hubCards.map(\.provider.id)
        XCTAssertEqual(ids.count, 2)
        XCTAssertTrue(Set(ids).isSubset(of: Set(registry.providers.map(\.id))))
        // Hub cards follow the local Claude card, ahead of Codex.
        XCTAssertEqual(Array(providers.map(\.provider.id).prefix(3)), ["claude"] + ids)
        // The account registry is not touched.
        XCTAssertNil(defaults.object(forKey: ProviderAccountsStore.storageKey))
    }

    func testMalformedConfigLoadsNoHubCards() async {
        let files = FakeFiles([CLIProxyHubConfigStore.path: "{broken"])
        let cards = await CLIProxyHubCards.loadRuntimes(
            store: CLIProxyHubConfigStore(files: files), http: RoutingHTTPClient { _ in Self.envelope(body: "{}") }
        )
        XCTAssertTrue(cards.all.isEmpty)
    }

    func testNewHubCardsAreEnabledOnceAndThenLeftToTheUser() throws {
        let defaults = makeScratchDefaults("CLIProxyHubEnablement")
        let enablement = ProviderEnablementStore(defaults: defaults)
        enablement.seedEnabledProviders(["claude"])
        enablement.registerKnownProviders(["claude"])
        let runtimes = CLIProxyHubCards.runtimes(
            hubs: [Self.hub(accounts: [Self.claude("claude-a.json")])], http: RoutingHTTPClient { _ in Self.envelope(body: "{}") }
        ).claude
        let id = try XCTUnwrap(runtimes.first?.provider.id)

        CLIProxyHubCards.enableNewCards(runtimes, enablement: enablement)
        XCTAssertTrue(enablement.isEnabled(id))
        XCTAssertTrue(enablement.knownIDs.contains(id))
        // Known now, so the new-provider seeder never probes it.
        XCTAssertNil(NewProviderSeeder.reconcileIfNeeded(providers: runtimes, enablement: enablement))

        enablement.setEnabled(false, for: id)
        CLIProxyHubCards.enableNewCards(runtimes, enablement: enablement)
        XCTAssertFalse(enablement.isEnabled(id))
    }
}
