import XCTest
@testable import OpenUsage

final class CLIProxyHubAccountSyncTests: XCTestCase {
    private let path = CLIProxyHubConfigStore.path

    private static let authFiles = """
    {"files": [
      {"id": "claude-new.json", "auth_index": "n1", "provider": "claude", "disabled": false, "email": "new@example.com"},
      {"id": "claude-old.json", "auth_index": "o1", "provider": "claude", "disabled": true, "email": "old@example.com"}
    ]}
    """

    private func account(_ id: String, authIndex: String, email: String) -> CLIProxyHubAccount {
        CLIProxyHubAccount(id: id, authIndex: authIndex, provider: .claude, email: email)
    }

    private var oldAccount: CLIProxyHubAccount { account("claude-old.json", authIndex: "o1", email: "old@example.com") }
    private var newAccount: CLIProxyHubAccount { account("claude-new.json", authIndex: "n1", email: "new@example.com") }

    private func seed(_ hubs: [CLIProxyHubConfig.Hub]) throws -> (CLIProxyHubConfigStore, FakeFiles) {
        let files = FakeFiles()
        let store = CLIProxyHubConfigStore(files: files)
        try store.save(CLIProxyHubConfig(hubs: hubs))
        return (store, files)
    }

    private func hub(_ id: String, enabled: Bool = true, accounts: [CLIProxyHubAccount]) -> CLIProxyHubConfig.Hub {
        .init(id: id, label: "Label \(id)", url: "https://\(id).example", managementKey: "key-\(id)",
              enabled: enabled, accounts: accounts)
    }

    private static func json(_ text: String, status: Int = 200) -> HTTPResponse {
        HTTPResponse(statusCode: status, headers: [:], body: Data(text.utf8))
    }

    func testSuccessfulSyncReplacesTheCacheAndDropsAccountsDisabledOnTheHub() async throws {
        let (store, _) = try seed([hub("one", accounts: [oldAccount])])
        let http = RoutingHTTPClient { _ in Self.json(Self.authFiles) }

        await CLIProxyHubAccountSync.run(store: store, http: http)

        XCTAssertEqual(http.requests.map(\.url.absoluteString), ["https://one.example/v0/management/auth-files"])
        XCTAssertEqual(try store.load().hubs.map(\.accounts), [[newAccount]])
    }

    func testWriteKeepsTheKeyAndEveryOtherField() async throws {
        let (store, _) = try seed([
            hub("one", accounts: [oldAccount]),
            hub("two", enabled: false, accounts: [oldAccount])
        ])
        let http = RoutingHTTPClient { _ in Self.json(Self.authFiles) }

        await CLIProxyHubAccountSync.run(store: store, http: http)

        XCTAssertEqual(try store.load(), CLIProxyHubConfig(hubs: [
            hub("one", accounts: [newAccount]),
            hub("two", enabled: false, accounts: [oldAccount])
        ]))
    }

    func testFailedSyncKeepsTheOldCacheAndLogsLoudly() async throws {
        let (store, files) = try seed([hub("one", accounts: [oldAccount])])
        let before = files.files[path]
        let http = RoutingHTTPClient { _ in Self.json("oops", status: 500) }

        let log = try await captureLog {
            await CLIProxyHubAccountSync.run(store: store, http: http)
        }

        XCTAssertEqual(files.files[path], before)
        XCTAssertTrue(log.contains("The hub could not list accounts."), log)
        XCTAssertTrue(log.contains("one"), log)
        XCTAssertFalse(log.contains("key-one"), log)
    }

    func testOneHubFailingStillSyncsTheNext() async throws {
        let (store, _) = try seed([hub("down", accounts: [oldAccount]), hub("up", accounts: [oldAccount])])
        let http = RoutingHTTPClient { request in
            if request.url.host == "down.example" { throw URLError(.cannotConnectToHost) }
            return Self.json(Self.authFiles)
        }

        await CLIProxyHubAccountSync.run(store: store, http: http)

        XCTAssertEqual(try store.load().hubs.map(\.accounts), [[oldAccount], [newAccount]])
    }

    func testDisabledHubsAreSkipped() async throws {
        let (store, _) = try seed([hub("off", enabled: false, accounts: [oldAccount])])
        let http = RoutingHTTPClient { _ in Self.json(Self.authFiles) }

        await CLIProxyHubAccountSync.run(store: store, http: http)

        XCTAssertTrue(http.requests.isEmpty)
        XCTAssertEqual(try store.load().hubs.map(\.accounts), [[oldAccount]])
    }

    func testRepeatedHubIDWritesToTheEnabledEntryThatWasRead() async throws {
        let off = CLIProxyHubConfig.Hub(id: "one", label: nil, url: "https://off.example", managementKey: "k-off",
                                        enabled: false, accounts: [oldAccount])
        let on = CLIProxyHubConfig.Hub(id: "one", label: nil, url: "https://on.example", managementKey: "k-on",
                                       enabled: true, accounts: [])
        let (store, _) = try seed([off, on])
        let http = RoutingHTTPClient { _ in Self.json(Self.authFiles) }

        await CLIProxyHubAccountSync.run(store: store, http: http)

        XCTAssertEqual(http.requests.map { $0.url.host }, ["on.example"])
        XCTAssertEqual(try store.load().hubs.map(\.accounts), [[oldAccount], [newAccount]])
    }

    func testUnchangedListIsNotRewritten() async throws {
        let files = FakeFiles([path: #"{"hubs": [{"id": "one", "url": "https://one.example", "managementKey": "k", "accounts": [{"id": "claude-new.json", "authIndex": "n1", "provider": "claude", "email": "new@example.com"}]}]}"#])
        let before = files.files[path]
        let http = RoutingHTTPClient { _ in Self.json(Self.authFiles) }

        await CLIProxyHubAccountSync.run(store: CLIProxyHubConfigStore(files: files), http: http)

        XCTAssertEqual(http.requests.count, 1)
        XCTAssertEqual(files.files[path], before)
    }

    // MARK: - Helpers

    /// Runs `body` with `AppLog` writing to a temporary file, and returns what was logged.
    private func captureLog(_ body: () async throws -> Void) async throws -> String {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("OpenUsageTests.CLIProxyHubSync.\(UUID().uuidString)", isDirectory: true)
        let sink = LogFile(directory: tempDir, fileName: "OpenUsage.log")
        sink.open()
        let originalSink = AppLog.sink
        AppLog.sink = sink
        AppLog.reloadLevel(.debug)
        defer {
            AppLog.sink = originalSink
            AppLog.reloadLevel()
            try? FileManager.default.removeItem(at: tempDir)
        }
        try await body()
        return (try? String(contentsOf: tempDir.appendingPathComponent("OpenUsage.log"), encoding: .utf8)) ?? ""
    }
}
