import XCTest
@testable import OpenUsage

@MainActor
final class CLIProxyHubSettingsTests: XCTestCase {
    private let path = CLIProxyHubConfigStore.path

    private func makeSettings(_ files: FakeFiles = FakeFiles()) -> (CLIProxyHubSettings, CLIProxyHubRelaunchNotice) {
        let notice = CLIProxyHubRelaunchNotice()
        let settings = CLIProxyHubSettings(
            store: CLIProxyHubConfigStore(files: files),
            notice: notice,
            syncAccounts: {}
        )
        settings.reload()
        return (settings, notice)
    }

    private func savedHubs(_ files: FakeFiles) throws -> [CLIProxyHubConfig.Hub] {
        try CLIProxyHubConfigStore(files: files).load().hubs
    }

    private func hub(_ id: String, url: String, accounts: [CLIProxyHubAccount] = []) -> CLIProxyHubConfig.Hub {
        .init(id: id, label: nil, url: url, managementKey: "old-key", enabled: true, accounts: accounts)
    }

    // MARK: - Hub id

    func testHubIDIsTheHostSlug() {
        XCTAssertEqual(
            CLIProxyHubSettings.hubID(for: URL(string: "https://Hub.Example.ts.net:8317/prefix")!, existing: []),
            "cliproxy-hub-example-ts-net"
        )
    }

    func testTakenHubIDsGetANumberSuffix() {
        let url = URL(string: "https://hub.example")!
        XCTAssertEqual(CLIProxyHubSettings.hubID(for: url, existing: ["cliproxy-hub-example"]), "cliproxy-hub-example-2")
        XCTAssertEqual(
            CLIProxyHubSettings.hubID(for: url, existing: ["CLIProxy-Hub-Example", "cliproxy-hub-example-2"]),
            "cliproxy-hub-example-3"
        )
    }

    // MARK: - Add

    func testAddingAHubWritesItAndOffersTheRelaunch() throws {
        let files = FakeFiles()
        let (settings, notice) = makeSettings(files)

        settings.addHub(url: "  https://hub.example.ts.net/ ", managementKey: " secret ", label: "  ")

        XCTAssertNil(settings.actionError)
        let hubs = try savedHubs(files)
        XCTAssertEqual(hubs, [CLIProxyHubConfig.Hub(
            id: "cliproxy-hub-example-ts-net", label: nil, url: "https://hub.example.ts.net",
            managementKey: "secret", enabled: true, accounts: []
        )])
        XCTAssertEqual(settings.hubs, hubs)
        XCTAssertTrue(notice.isPending)
    }

    func testAddingAHubOnAnExistingHostGetsTheNextID() throws {
        let files = FakeFiles()
        let (settings, _) = makeSettings(files)

        settings.addHub(url: "https://hub.example/one", managementKey: "k1", label: "One")
        settings.addHub(url: "https://hub.example/two", managementKey: "k2", label: "Two")

        XCTAssertEqual(try savedHubs(files).map(\.id), ["cliproxy-hub-example", "cliproxy-hub-example-2"])
        XCTAssertEqual(try savedHubs(files).map(\.label), ["One", "Two"])
    }

    func testAddingASavedURLKeepsItsIDAndAccounts() throws {
        let account = CLIProxyHubAccount(id: "a.json", authIndex: "1", provider: .claude, email: "a@example.com")
        let files = FakeFiles()
        try CLIProxyHubConfigStore(files: files).save(CLIProxyHubConfig(hubs: [
            hub("cliproxy-home", url: "https://hub.example", accounts: [account])
        ]))
        let (settings, _) = makeSettings(files)

        settings.addHub(url: "https://HUB.example/", managementKey: "new-key", label: "Home")

        let hubs = try savedHubs(files)
        XCTAssertEqual(hubs.map(\.id), ["cliproxy-home"])
        XCTAssertEqual(hubs.first?.managementKey, "new-key")
        XCTAssertEqual(hubs.first?.label, "Home")
        XCTAssertEqual(hubs.first?.accounts, [account])
    }

    func testAddingASavedURLKeepsItsOnOffState() throws {
        let files = FakeFiles()
        var disabled = hub("cliproxy-home", url: "https://hub.example")
        disabled.enabled = false
        try CLIProxyHubConfigStore(files: files).save(CLIProxyHubConfig(hubs: [disabled]))
        let (settings, _) = makeSettings(files)

        settings.addHub(url: "https://hub.example", managementKey: "new-key", label: "")

        XCTAssertEqual(try savedHubs(files).map(\.enabled), [false])
    }

    func testAFailedSaveIsAFriendlyErrorWithoutRelaunchOrSync() async throws {
        let files = UnwritableFiles()
        let notice = CLIProxyHubRelaunchNotice()
        let synced = expectation(description: "account sync ran")
        synced.isInverted = true
        let settings = CLIProxyHubSettings(
            store: CLIProxyHubConfigStore(files: files), notice: notice, syncAccounts: { synced.fulfill() }
        )
        settings.reload()

        settings.addHub(url: "https://hub.example", managementKey: "k", label: "")

        XCTAssertNotNil(settings.actionError)
        XCTAssertEqual(settings.hubs, [])
        XCTAssertFalse(notice.isPending)
        await fulfillment(of: [synced], timeout: 0.2)
    }

    func testAnInvalidURLIsAFriendlyErrorAndWritesNothing() {
        let files = FakeFiles()
        let (settings, notice) = makeSettings(files)

        settings.addHub(url: "hub.example", managementKey: "k", label: "")

        XCTAssertNotNil(settings.actionError)
        XCTAssertNil(files.files[path])
        XCTAssertFalse(notice.isPending)
    }

    func testTheErrorClearsWhenDismissedOrReloaded() {
        let (settings, _) = makeSettings()

        settings.addHub(url: "hub.example", managementKey: "k", label: "")
        settings.clearActionError()
        XCTAssertNil(settings.actionError)

        settings.addHub(url: "hub.example", managementKey: "k", label: "")
        settings.reload()
        XCTAssertNil(settings.actionError)
    }

    func testSaveRunsTheAccountSync() async {
        let synced = expectation(description: "account sync ran")
        let settings = CLIProxyHubSettings(
            store: CLIProxyHubConfigStore(files: FakeFiles()),
            notice: CLIProxyHubRelaunchNotice(),
            syncAccounts: { synced.fulfill() }
        )
        settings.reload()

        settings.addHub(url: "https://hub.example", managementKey: "k", label: "")

        await fulfillment(of: [synced], timeout: 1)
    }

    func testSavesDuringASyncQueueOneMorePassInsteadOfAnotherSync() async {
        let probe = SyncProbe()
        let settings = CLIProxyHubSettings(
            store: CLIProxyHubConfigStore(files: FakeFiles()),
            notice: CLIProxyHubRelaunchNotice(),
            syncAccounts: { await probe.sync() }
        )
        settings.reload()

        settings.addHub(url: "https://one.example", managementKey: "k", label: "")
        await waitUntil { await probe.calls == 1 }
        settings.addHub(url: "https://two.example", managementKey: "k", label: "")
        settings.addHub(url: "https://three.example", managementKey: "k", label: "")
        for _ in 0..<50 { await Task.yield() }
        let callsWhileBusy = await probe.calls
        XCTAssertEqual(callsWhileBusy, 1)

        await probe.release()
        await waitUntil { await probe.calls == 2 }
        for _ in 0..<50 { await Task.yield() }
        let callsAfter = await probe.calls
        XCTAssertEqual(callsAfter, 2)
    }

    private func waitUntil(_ condition: () async -> Bool) async {
        for _ in 0..<1_000 {
            if await condition() { return }
            await Task.yield()
        }
        XCTFail("condition never became true")
    }

    // MARK: - Disable / remove

    func testDisablingAndRemovingAHubWriteTheConfig() throws {
        let files = FakeFiles()
        try CLIProxyHubConfigStore(files: files).save(CLIProxyHubConfig(hubs: [
            hub("one", url: "https://one.example"), hub("two", url: "https://two.example")
        ]))
        let (settings, notice) = makeSettings(files)

        settings.setEnabled(false, hubID: "one")
        XCTAssertEqual(try savedHubs(files).map(\.enabled), [false, true])
        XCTAssertTrue(notice.isPending)

        settings.remove(hubID: "two")
        XCTAssertEqual(try savedHubs(files).map(\.id), ["one"])
        XCTAssertEqual(settings.hubs.map(\.id), ["one"])
    }

    // MARK: - Broken config

    func testAnUnreadableConfigIsShownAndNeverOverwritten() {
        let files = FakeFiles([path: "{not json"])
        let (settings, notice) = makeSettings(files)

        XCTAssertNotNil(settings.loadError)
        XCTAssertEqual(settings.hubs, [])

        settings.addHub(url: "https://hub.example", managementKey: "k", label: "")
        settings.remove(hubID: "anything")

        XCTAssertEqual(files.files[path], "{not json")
        XCTAssertFalse(notice.isPending)
    }

    func testReloadClearsTheErrorOnceTheFileIsFixed() {
        let files = FakeFiles([path: "{not json"])
        let (settings, _) = makeSettings(files)
        XCTAssertNotNil(settings.loadError)

        files.files[path] = #"{"hubs": []}"#
        settings.reload()

        XCTAssertNil(settings.loadError)
    }
}

private struct UnwritableFiles: TextFileAccessing {
    struct WriteFailed: Error {}

    func exists(_ path: String) -> Bool { false }
    func readTextIfPresent(_ path: String) throws -> String? { nil }
    func readText(_ path: String) throws -> String { "" }
    func writeText(_ path: String, _ text: String) throws { throw WriteFailed() }
    func remove(_ path: String) throws {}
}

/// Counts account syncs; each one waits until `release()` so a test can save while one runs.
private actor SyncProbe {
    private(set) var calls = 0
    private var released = false
    private var waiting: [CheckedContinuation<Void, Never>] = []

    func sync() async {
        calls += 1
        guard !released else { return }
        await withCheckedContinuation { waiting.append($0) }
    }

    func release() {
        released = true
        waiting.forEach { $0.resume() }
        waiting = []
    }
}
