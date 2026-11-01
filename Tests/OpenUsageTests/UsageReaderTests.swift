import XCTest
@testable import OpenUsage

@MainActor
final class UsageReaderTests: XCTestCase {
    private final class StubProvider: ProviderRuntime {
        let provider: Provider
        var widgetDescriptors: [WidgetDescriptor] {
            [WidgetDescriptor.percent(id: "\(provider.id).weekly", provider: provider, title: "Weekly")
                .exportingLimit("weekly", unit: "percent")]
        }
        var refreshCount = 0
        var refreshError: String?
        var refreshedAt = Date()

        init(id: String = "stub") {
            self.provider = Provider(id: id, displayName: id.capitalized, icon: .providerMark(id))
        }

        func hasLocalCredentials() async -> Bool { true }

        func refresh() async -> ProviderSnapshot {
            refreshCount += 1
            if let refreshError {
                return .error(provider: provider, message: refreshError)
            }
            return ProviderSnapshot(
                providerID: provider.id,
                displayName: provider.displayName,
                lines: [.progress(label: "Weekly", used: 20, limit: 100, format: .percent)],
                refreshedAt: refreshedAt
            )
        }
    }

    private func defaults() -> UserDefaults {
        let suite = "UsageReaderTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    func testReadsSharedSnapshotCacheWithoutRefreshing() async throws {
        let defaults = defaults()
        let provider = StubProvider()
        ProviderSnapshotCache(userDefaults: defaults).store(await provider.refresh())
        provider.refreshCount = 0

        let result = try await UsageReader(userDefaults: defaults, providers: [provider]).read(providerID: "stub")
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: result.data) as? [String: Any])

        XCTAssertNotNil((object["providers"] as? [String: Any])?["stub"])
        XCTAssertEqual(provider.refreshCount, 0)
        XCTAssertTrue(result.warnings.isEmpty)
    }

    func testForceUsesSharedProviderAndStoresResult() async throws {
        let defaults = defaults()
        let provider = StubProvider()
        let reader = UsageReader(userDefaults: defaults, providers: [provider])

        let result = try await reader.read(providerID: "stub", force: true)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: result.data) as? [String: Any])
        let cached = ProviderSnapshotCache(userDefaults: defaults).loadSnapshots(providerIDs: ["stub"])

        XCTAssertEqual(provider.refreshCount, 1)
        XCTAssertNotNil((object["providers"] as? [String: Any])?["stub"])
        XCTAssertEqual(cached["stub"]?.line(label: "Weekly"), .progress(
            label: "Weekly", used: 20, limit: 100, format: .percent
        ))
    }

    func testRefreshAllPersistsSnapshotsBeforeOneShotReaderReturns() async throws {
        let defaults = defaults()
        defaults.set(["alpha", "beta"], forKey: "openusage.enabledProviders.v1")
        let providers = [StubProvider(id: "alpha"), StubProvider(id: "beta")]

        _ = try await UsageReader(userDefaults: defaults, providers: providers).read(force: true)

        let persisted = ProviderSnapshotCache(userDefaults: defaults).loadSnapshots(providerIDs: ["alpha", "beta"])
        XCTAssertEqual(Set(persisted.keys), Set(["alpha", "beta"]))
    }

    func testStalePersistedSnapshotRefreshesBeforeReading() async throws {
        let defaults = defaults()
        let provider = StubProvider()
        provider.refreshedAt = Date().addingTimeInterval(-RefreshSetting.interval - 1)
        ProviderSnapshotCache(userDefaults: defaults).store(await provider.refresh())
        provider.refreshCount = 0
        provider.refreshedAt = Date()

        let result = try await UsageReader(userDefaults: defaults, providers: [provider]).read(providerID: "stub")
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: result.data) as? [String: Any])

        XCTAssertNotNil((object["providers"] as? [String: Any])?["stub"])
        XCTAssertEqual(provider.refreshCount, 1)
    }

    func testForcedProviderReadRefreshesOnlyRequestedProvider() async throws {
        let defaults = defaults()
        let requested = StubProvider(id: "requested")
        let other = StubProvider(id: "other")

        _ = try await UsageReader(userDefaults: defaults, providers: [requested, other])
            .read(providerID: "requested", force: true)

        XCTAssertEqual(requested.refreshCount, 1)
        XCTAssertEqual(other.refreshCount, 0)
    }

    func testUnknownProviderFailsBeforeRefresh() async {
        let defaults = defaults()
        let provider = StubProvider()

        do {
            _ = try await UsageReader(userDefaults: defaults, providers: [provider]).read(providerID: "missing", force: true)
            XCTFail("Expected unknown provider error")
        } catch UsageReaderError.unknownProvider(let providerID) {
            XCTAssertEqual(providerID, "missing")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        XCTAssertEqual(provider.refreshCount, 0)
    }

    func testFailedForceWithoutCacheReturnsMachineReadableError() async throws {
        let defaults = defaults()
        let provider = StubProvider()
        provider.refreshError = "Not logged in"

        let result = try await UsageReader(userDefaults: defaults, providers: [provider])
            .read(providerID: "stub", force: true)
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: result.data) as? [String: Any])
        let errors = try XCTUnwrap(root["errors"] as? [[String: Any]])

        XCTAssertEqual(result.warnings, ["stub: Not logged in"])
        XCTAssertEqual(errors.first?["providerId"] as? String, "stub")
        XCTAssertEqual(errors.first?["message"] as? String, "Not logged in")
    }

    /// The CLI and the local HTTP API serve hub cards as part of the `claude` family, from the same
    /// hub card runtimes the app builds.
    func testHubCardLimitsAreServedUnderTheClaudeFamily() async throws {
        let usage = #"{"five_hour":{"utilization":10,"resets_at":"2099-01-01T00:00:00.000Z"},"seven_day":{"utilization":20,"resets_at":"2099-01-01T00:00:00.000Z"}}"#
        let envelope = try JSONSerialization.data(withJSONObject: ["status_code": 200, "header": [:] as [String: Any], "body": usage])
        let hubCards = CLIProxyHubCards.runtimes(
            hubs: [CLIProxyHubConfig.Hub(
                id: "hub", label: "Home", url: "https://hub.example.ts.net", managementKey: "key", enabled: true,
                accounts: [CLIProxyHubAccount(id: "claude-a.json", authIndex: "a1", provider: .claude)]
            )],
            http: RoutingHTTPClient { _ in HTTPResponse(statusCode: 200, headers: [:], body: envelope) }
        ).claude
        let cardID = try XCTUnwrap(hubCards.first?.provider.id)

        let result = try await UsageReader(userDefaults: defaults(), providers: hubCards)
            .read(providerID: "claude", force: true)
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: result.data) as? [String: Any])
        let card = try XCTUnwrap((root["providers"] as? [String: Any])?[cardID] as? [String: Any])
        let resources = try XCTUnwrap(card["resources"] as? [String: Any])

        XCTAssertEqual(result.warnings, [])
        XCTAssertNotNil(resources["session"])
        XCTAssertNotNil(resources["weekly"])
    }

    /// Codex hub cards are served under the `codex` family the same way.
    func testCodexHubCardLimitsAreServedUnderTheCodexFamily() async throws {
        let usage = #"{"plan_type":"pro","rate_limit":{"primary_window":{"used_percent":10,"limit_window_seconds":18000,"reset_after_seconds":60},"secondary_window":{"used_percent":20,"limit_window_seconds":604800,"reset_after_seconds":600}}}"#
        let envelope = try JSONSerialization.data(withJSONObject: ["status_code": 200, "header": [:] as [String: Any], "body": usage])
        let hubCards = CLIProxyHubCards.runtimes(
            hubs: [CLIProxyHubConfig.Hub(
                id: "hub", label: "Home", url: "https://hub.example.ts.net", managementKey: "key", enabled: true,
                accounts: [CLIProxyHubAccount(id: "codex-a.json", authIndex: "c1", provider: .codex)]
            )],
            http: RoutingHTTPClient { _ in HTTPResponse(statusCode: 200, headers: [:], body: envelope) }
        ).codex
        let cardID = try XCTUnwrap(hubCards.first?.provider.id)

        let result = try await UsageReader(userDefaults: defaults(), providers: hubCards)
            .read(providerID: "codex", force: true)
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: result.data) as? [String: Any])
        let card = try XCTUnwrap((root["providers"] as? [String: Any])?[cardID] as? [String: Any])
        let resources = try XCTUnwrap(card["resources"] as? [String: Any])

        XCTAssertEqual(result.warnings, [])
        XCTAssertNotNil(resources["session"])
        XCTAssertNotNil(resources["weekly"])
    }
}
