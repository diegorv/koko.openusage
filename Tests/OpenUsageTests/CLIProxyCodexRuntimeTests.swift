import XCTest
@testable import OpenUsage

@MainActor
final class CLIProxyCodexRuntimeTests: XCTestCase {
    nonisolated private static let usageBody = """
    {
      "plan_type": "pro",
      "rate_limit": {
        "primary_window": { "used_percent": 10, "limit_window_seconds": 18000, "reset_after_seconds": 60 },
        "secondary_window": { "used_percent": 20, "limit_window_seconds": 604800, "reset_after_seconds": 600 }
      },
      "credits": { "balance": 12.5 }
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

    nonisolated private static func codex(
        _ id: String, email: String? = nil, accountID: String? = nil, plan: String? = nil
    ) -> CLIProxyHubAccount {
        CLIProxyHubAccount(
            id: id, authIndex: "idx-\(id)", provider: .codex, email: email, chatgptAccountID: accountID, planType: plan
        )
    }

    nonisolated private static func envelope(status: Int = 200, body: String) -> HTTPResponse {
        let object: [String: Any] = ["status_code": status, "header": [:] as [String: Any], "body": body]
        return HTTPResponse(statusCode: 200, headers: [:], body: try! JSONSerialization.data(withJSONObject: object))
    }

    /// The `api-call` payload the hub received: `auth_index`, the upstream `url` and its `header`.
    nonisolated private static func payload(_ request: HTTPRequest) -> [String: Any] {
        (request.body.flatMap { try? JSONSerialization.jsonObject(with: $0) } as? [String: Any]) ?? [:]
    }

    private func firstCard(hubs: [CLIProxyHubConfig.Hub], http: any HTTPClient) throws -> CLIProxyCodexRuntime {
        try XCTUnwrap(CLIProxyHubCards.runtimes(hubs: hubs, http: http).codex.first)
    }

    private func errorText(_ snapshot: ProviderSnapshot) -> String? {
        for case .badge(let label, let text, _, _) in snapshot.lines where label == MetricLine.errorBadgeLabel {
            return text
        }
        return nil
    }

    // MARK: - Limits

    func testMapsTheAccountsLimitsThroughTheHubWithTheCodexHeaders() async throws {
        let http = RoutingHTTPClient { _ in Self.envelope(body: Self.usageBody) }
        let runtime = try firstCard(
            hubs: [Self.hub(accounts: [Self.codex("codex-a.json", email: "a@example.com", accountID: "acct-a")])],
            http: http
        )

        let snapshot = await runtime.refresh()

        XCTAssertNil(errorText(snapshot))
        XCTAssertEqual(snapshot.lines.map(\.label), ["Session", "Weekly", "Credits"])
        XCTAssertEqual(snapshot.plan, "Pro 200")
        let payload = Self.payload(try XCTUnwrap(http.requests.first))
        XCTAssertEqual(payload["auth_index"] as? String, "idx-codex-a.json")
        XCTAssertEqual(payload["method"] as? String, "GET")
        XCTAssertEqual(payload["url"] as? String, "https://chatgpt.com/backend-api/wham/usage")
        let header = try XCTUnwrap(payload["header"] as? [String: String])
        XCTAssertEqual(header["OpenAI-Beta"], "codex-1")
        XCTAssertEqual(header["Originator"], "Codex Desktop")
        XCTAssertEqual(header["Chatgpt-Account-Id"], "acct-a")
        XCTAssertEqual(header["Authorization"], CLIProxyHubClient.tokenPlaceholder)
    }

    func testLeavesOutTheAccountHeaderWhenTheAccountIDIsUnknown() async throws {
        let http = RoutingHTTPClient { _ in Self.envelope(body: Self.usageBody) }
        let runtime = try firstCard(hubs: [Self.hub(accounts: [Self.codex("codex-a.json")])], http: http)

        _ = await runtime.refresh()

        let header = try XCTUnwrap(Self.payload(try XCTUnwrap(http.requests.first))["header"] as? [String: String])
        XCTAssertFalse(header.keys.contains { $0.lowercased() == "chatgpt-account-id" })
        XCTAssertEqual(header["OpenAI-Beta"], "codex-1")
    }

    func testShowsLimitsOnlyWithTheCodexMetricIDs() throws {
        let runtime = try firstCard(
            hubs: [Self.hub(accounts: [Self.codex("codex-a.json")])], http: RoutingHTTPClient { _ in Self.envelope(body: "{}") }
        )
        let id = runtime.provider.id

        XCTAssertEqual(runtime.widgetDescriptors.map(\.id), [
            "\(id).session", "\(id).weekly", "\(id).spark", "\(id).sparkWeekly", "\(id).credits", "\(id).rateLimitResets"
        ])
        XCTAssertFalse(runtime.widgetDescriptors.contains { $0.isSpendTile || $0.historyResource != nil })
        // Same suffixes as the local Codex card, so `DefaultLayout.expandingAccounts` gives hub cards
        // the Codex family's defaults.
        let local = Set(CodexProvider().widgetDescriptors.map(\.id))
        XCTAssertTrue(runtime.widgetDescriptors.allSatisfy { local.contains("codex" + $0.id.dropFirst(id.count)) })
    }

    func testPlanFallsBackToTheAccountsIDTokenPlan() async throws {
        let body = #"{"rate_limit":{"primary_window":{"used_percent":10,"limit_window_seconds":18000}}}"#
        let runtime = try firstCard(
            hubs: [Self.hub(accounts: [Self.codex("codex-a.json", plan: "plus")])],
            http: RoutingHTTPClient { _ in Self.envelope(body: body) }
        )

        let snapshot = await runtime.refresh()

        XCTAssertNil(errorText(snapshot))
        XCTAssertEqual(snapshot.plan, "Plus")
    }

    func testUpstreamUnauthorizedAsksForAHubReloginWithoutRefreshingOrWriting() async throws {
        let files = FakeFiles()
        let store = CLIProxyHubConfigStore(files: files)
        try store.save(CLIProxyHubConfig(hubs: [Self.hub(accounts: [Self.codex("codex-a.json")])]))
        let before = files.files
        let http = RoutingHTTPClient { _ in Self.envelope(status: 401, body: #"{"error":"invalid_token"}"#) }
        let runtime = try firstCard(hubs: try store.load().hubs, http: http)

        let snapshot = await runtime.refresh()

        XCTAssertEqual(errorText(snapshot), CLIProxyHubAccountError.reloginRequired.localizedDescription)
        XCTAssertEqual(snapshot.errorCategory, .authExpired)
        XCTAssertEqual(http.requests.count, 1, "no token refresh and no retry")
        XCTAssertEqual(Self.payload(http.requests[0])["url"] as? String, "https://chatgpt.com/backend-api/wham/usage")
        XCTAssertEqual(files.files, before)
    }

    func testHubCardsAreNeverLocalCredentials() async throws {
        let runtime = try firstCard(
            hubs: [Self.hub(accounts: [Self.codex("codex-a.json")])], http: RoutingHTTPClient { _ in Self.envelope(body: "{}") }
        )
        let hasCredentials = await runtime.hasLocalCredentials()
        XCTAssertFalse(hasCredentials)
        let detected = await FirstRunSeeder.detectLocalProviders([runtime])
        XCTAssertEqual(detected, [])
    }

    // MARK: - Cards

    func testCardsAreNamedForTheHubInTheCodexFamily() {
        let account = Self.codex("codex-a.json", email: "a@example.com")
        let runtimes = CLIProxyHubCards.runtimes(
            hubs: [Self.hub(accounts: [account, CLIProxyHubAccount(id: "claude.json", authIndex: "c", provider: .claude)])],
            http: RoutingHTTPClient { _ in Self.envelope(body: "{}") }
        ).codex

        XCTAssertEqual(runtimes.map(\.account.id), ["codex-a.json"])
        XCTAssertEqual(
            runtimes.first?.provider.id,
            ProviderAccountID.make(family: "codex", identityKey: "cliproxy:cliproxy-hub-example:codex-a.json")
        )
        XCTAssertEqual(ProviderAccountID.family(of: runtimes[0].provider.id), "codex")
        XCTAssertEqual(runtimes.first?.provider.displayName, "Codex: a@example.com (Hub Home)")
    }

    func testClaudeAndCodexCardsOfOneHubShareItsSession() {
        let runtimes = CLIProxyHubCards.runtimes(
            hubs: [Self.hub(accounts: [
                CLIProxyHubAccount(id: "claude.json", authIndex: "c", provider: .claude), Self.codex("codex-a.json")
            ])],
            http: RoutingHTTPClient { _ in Self.envelope(body: "{}") }
        )

        XCTAssertEqual(runtimes.claude.count, 1)
        XCTAssertEqual(runtimes.codex.count, 1)
        XCTAssertTrue(runtimes.claude[0].session === runtimes.codex[0].session)
    }

    func testLaunchPlacesCodexHubCardsAfterTheLocalCodexCardWithoutTheNetwork() async throws {
        let defaults = makeScratchDefaults("CLIProxyCodexHubLaunch")
        let files = FakeFiles()
        try CLIProxyHubConfigStore(files: files).save(CLIProxyHubConfig(hubs: [
            Self.hub(accounts: [Self.codex("codex-a.json"), CLIProxyHubAccount(id: "claude.json", authIndex: "c", provider: .claude)])
        ]))
        let http = RoutingHTTPClient { _ in throw URLError(.cannotConnectToHost) }

        let hubCards = await CLIProxyHubCards.loadRuntimes(store: CLIProxyHubConfigStore(files: files), http: http)
        let providers = ProviderCatalog.make(defaults: defaults, hubCards: hubCards.claude, codexHubCards: hubCards.codex)
        let ids = providers.map(\.provider.id)

        XCTAssertEqual(http.requests.count, 0)
        let codexID = try XCTUnwrap(hubCards.codex.first?.provider.id)
        let claudeID = try XCTUnwrap(hubCards.claude.first?.provider.id)
        XCTAssertEqual(Array(ids.prefix(4)), ["claude", claudeID, "codex", codexID])
        XCTAssertEqual(Set(hubCards.all.map(\.provider.id)), [codexID, claudeID])
        _ = WidgetDataStore(
            registry: WidgetRegistry.from(providers), providers: providers,
            cache: ProviderSnapshotCache(userDefaults: defaults), defaults: defaults
        )
    }
}
