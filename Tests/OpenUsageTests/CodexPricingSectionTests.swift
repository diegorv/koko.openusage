import XCTest
@testable import OpenUsage

@MainActor
final class CodexPricingSectionTests: XCTestCase {
    private let hubCards = CLIProxyHubCards.runtimes(
        hubs: [CLIProxyHubConfig.Hub(
            id: "hub", label: nil, url: "https://hub.example.ts.net", managementKey: "key", enabled: true,
            accounts: [CLIProxyHubAccount(id: "codex-a.json", authIndex: "c1", provider: .codex)]
        )],
        http: RoutingHTTPClient { _ in throw URLError(.cannotConnectToHost) }
    )

    private var providers: [ProviderRuntime] {
        [LocalCard("claude"), LocalCard("codex"), LocalCard("codex@ab12cd34")] + hubCards.all
    }

    /// The fallback model prices local spend, so a local Codex card shows it and changing it
    /// refreshes only the local Codex cards.
    func testLocalCodexCardPricesOnlyLocalCodexCards() {
        XCTAssertEqual(
            CodexPricingSection.cardIDs(for: "codex", among: providers),
            ["codex", "codex@ab12cd34"]
        )
    }

    /// Hub cards show limits only, with no spend to estimate.
    func testHubCodexCardHasNoCostEstimates() throws {
        let hubID = try XCTUnwrap(hubCards.codex.first?.provider.id)
        XCTAssertNil(CodexPricingSection.cardIDs(for: hubID, among: providers))
    }

    func testOtherFamiliesHaveNoCostEstimates() {
        XCTAssertNil(CodexPricingSection.cardIDs(for: "claude", among: providers))
    }
}

@MainActor
private final class LocalCard: ProviderRuntime {
    let provider: Provider
    let widgetDescriptors: [WidgetDescriptor] = []

    init(_ id: String) {
        provider = Provider(id: id, displayName: id, icon: .providerMark(id))
    }

    func hasLocalCredentials() async -> Bool { true }

    func refresh() async -> ProviderSnapshot {
        ProviderSnapshot.make(provider: provider, plan: nil, lines: [], refreshedAt: Date())
    }
}
