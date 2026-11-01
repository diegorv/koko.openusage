import XCTest
@testable import OpenUsage

/// When an account is signed in both on this Mac and on a hub, the hub card wins and the local card
/// is left out at launch.
@MainActor
final class CLIProxyHubLocalMatchTests: XCTestCase {
    private static func hub(enabled: Bool = true, accounts: [CLIProxyHubAccount]) -> CLIProxyHubConfig.Hub {
        CLIProxyHubConfig.Hub(
            id: "cliproxy-hub-example", label: "Home", url: "https://hub.example.com",
            managementKey: "key", enabled: enabled, accounts: accounts
        )
    }

    private static func runtimes(_ hubs: [CLIProxyHubConfig.Hub]) -> CLIProxyHubCards.Runtimes {
        CLIProxyHubCards.runtimes(hubs: hubs, http: RoutingHTTPClient { _ in throw URLError(.cannotConnectToHost) })
    }

    private static func claude(_ id: String, email: String?) -> CLIProxyHubAccount {
        CLIProxyHubAccount(id: id, authIndex: id, provider: .claude, email: email)
    }

    private static func codex(_ id: String, email: String?, accountID: String?) -> CLIProxyHubAccount {
        CLIProxyHubAccount(id: id, authIndex: id, provider: .codex, email: email, chatgptAccountID: accountID)
    }

    func testClaudeMatchesByEmailIgnoringCase() {
        let local = [
            CLIProxyHubLocalAccount(cardID: "claude", family: .claude, email: "Dev@Example.com"),
            CLIProxyHubLocalAccount(cardID: "claude-other", family: .claude, email: "other@example.com"),
        ]
        let hidden = CLIProxyHubCards.hiddenLocalCardIDs(
            local: local, hub: Self.runtimes([Self.hub(accounts: [Self.claude("a.json", email: "dev@example.com")])])
        )
        XCTAssertEqual(hidden, ["claude"])
    }

    func testCodexMatchesByAccountIDThenFallsBackToEmail() {
        let local = [
            CLIProxyHubLocalAccount(cardID: "codex-a", family: .codex, email: "a@example.com", chatgptAccountID: "acct-a"),
            CLIProxyHubLocalAccount(cardID: "codex-b", family: .codex, email: "b@example.com", chatgptAccountID: "acct-b"),
            CLIProxyHubLocalAccount(cardID: "codex-c", family: .codex, email: "c@example.com", chatgptAccountID: "acct-c"),
        ]
        let hub = Self.runtimes([Self.hub(accounts: [
            // Same id, different email: still the same account.
            Self.codex("a.json", email: "renamed@example.com", accountID: "ACCT-A"),
            // The hub doesn't know the id: email decides.
            Self.codex("b.json", email: "B@example.com", accountID: nil),
            // Same email, different workspace: a different usage pool, not a match.
            Self.codex("c.json", email: "c@example.com", accountID: "acct-other"),
        ])])

        XCTAssertEqual(CLIProxyHubCards.hiddenLocalCardIDs(local: local, hub: hub), ["codex-a", "codex-b"])
    }

    func testNoMatchAcrossFamiliesOrWithoutAnEmail() {
        let local = [
            CLIProxyHubLocalAccount(cardID: "claude", family: .claude, email: nil),
            CLIProxyHubLocalAccount(cardID: "codex", family: .codex, email: "dev@example.com"),
        ]
        let hub = Self.runtimes([Self.hub(accounts: [Self.claude("a.json", email: "dev@example.com")])])

        XCTAssertEqual(CLIProxyHubCards.hiddenLocalCardIDs(local: local, hub: hub), [])
    }

    func testDisabledHubHidesNothing() {
        let local = [CLIProxyHubLocalAccount(cardID: "claude", family: .claude, email: "dev@example.com")]
        let hub = Self.runtimes([Self.hub(enabled: false, accounts: [Self.claude("a.json", email: "dev@example.com")])])

        XCTAssertEqual(CLIProxyHubCards.hiddenLocalCardIDs(local: local, hub: hub), [])
    }

    func testCatalogLeavesOutOnlyTheHiddenLocalCard() {
        let hub = Self.runtimes([Self.hub(accounts: [Self.claude("a.json", email: "dev@example.com")])])
        let providers = ProviderCatalog.make(hubCards: hub.claude, hiddenLocalCardIDs: ["claude"])
        let ids = providers.map(\.provider.id)

        XCTAssertFalse(ids.contains("claude"))
        XCTAssertTrue(ids.contains("codex"))
        XCTAssertTrue(ids.contains(hub.claude[0].provider.id))
    }

    /// The launch account pass names each local card's account, so the hub match has something to
    /// compare: the plain Claude card by its state-file email, the plain Codex card by its token.
    func testAssemblyNamesThePlainCardsAccounts() async {
        let suiteName = "OpenUsageTests.CLIProxyHubLocalMatch.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        addTeardownBlock { defaults.removePersistentDomain(forName: suiteName) }
        let idToken = Self.jwt(#"{"email":"Codex@Example.com","https://api.openai.com/auth":{"chatgpt_account_id":"acct-1"}}"#)
        let observer = DefaultAccountObserver(
            environment: FakeEnvironment([:]),
            files: FakeFiles([
                "/Users/dev/.claude.json": #"{"oauthAccount": {"accountUuid": "ACCT-1", "emailAddress": "Dev@Example.com"}}"#,
                "/Users/dev/.codex/auth.json": #"{"tokens": {"access_token": "at-1", "id_token": "\#(idToken)"}}"#,
            ]),
            keychain: FakeKeychain(nil),
            homeDirectory: { URL(fileURLWithPath: "/Users/dev") }
        )

        let assembly = await ProviderAccountAssembly.make(
            observer: observer, accountsStore: ProviderAccountsStore(defaults: defaults)
        )

        XCTAssertEqual(assembly.localAccounts, [
            CLIProxyHubLocalAccount(cardID: "claude", family: .claude, email: "dev@example.com"),
            CLIProxyHubLocalAccount(cardID: "codex", family: .codex, email: "codex@example.com", chatgptAccountID: "acct-1"),
        ])
    }

    /// With Swap slots the pass builds account cards: a Swap card names its slot email, and the
    /// default login's org card picks up the state-file email through its account UUID.
    func testAssemblyNamesTheClaudeAccountCardsAccounts() async {
        let suiteName = "OpenUsageTests.CLIProxyHubLocalMatch.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        addTeardownBlock { defaults.removePersistentDomain(forName: suiteName) }
        let defaultUser = "11111111-1111-1111-1111-111111111111"
        let observer = DefaultAccountObserver(
            environment: FakeEnvironment([:]),
            files: FakeFiles([
                "/Users/dev/.claude.json": #"{"oauthAccount": {"accountUuid": "\#(defaultUser)", "organizationUuid": "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa", "emailAddress": "Dev@Example.com"}}"#,
                "/Users/dev/.claude-swap-backup/sequence.json": #"""
                {"accounts":{"1":{"email":"Slot@Example.com","uuid":"22222222-2222-2222-2222-222222222222","organizationUuid":"bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"}}}
                """#,
            ]),
            keychain: FakeKeychain(nil),
            homeDirectory: { URL(fileURLWithPath: "/Users/dev") }
        )

        let assembly = await ProviderAccountAssembly.make(
            observer: observer, accountsStore: ProviderAccountsStore(defaults: defaults)
        )

        let claude = assembly.localAccounts.filter { $0.family == .claude }
        XCTAssertEqual(claude.count, 2)
        let swapCard = assembly.claudeCards.first { $0.swapAccount != nil }
        let orgCard = assembly.claudeCards.first { $0.swapAccount == nil && $0.identityKey.hasPrefix(defaultUser) }
        XCTAssertEqual(claude.first { $0.cardID == swapCard?.id }?.email, "slot@example.com")
        XCTAssertEqual(claude.first { $0.cardID == orgCard?.id }?.email, "dev@example.com")
    }

    private static func jwt(_ payload: String) -> String {
        let encoded = Data(payload.utf8).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return "e30.\(encoded).sig"
    }
}
