import XCTest
@testable import OpenUsage

final class CLIProxyHubConfigStoreTests: XCTestCase {
    private let path = CLIProxyHubConfigStore.path

    private func account(_ id: String, email: String? = nil) -> CLIProxyHubAccount {
        CLIProxyHubAccount(id: id, authIndex: "idx-\(id)", provider: .claude, email: email)
    }

    func testMissingFileIsAnEmptyHubList() throws {
        let store = CLIProxyHubConfigStore(files: FakeFiles())
        XCTAssertEqual(try store.load(), CLIProxyHubConfig(hubs: []))
    }

    func testHubListAndCachedAccountsRoundTrip() throws {
        let files = FakeFiles()
        let store = CLIProxyHubConfigStore(files: files)
        let config = CLIProxyHubConfig(hubs: [
            CLIProxyHubConfig.Hub(
                id: "cliproxy-hub-example-ts-net", label: "Home", url: "https://hub.example.ts.net",
                managementKey: "key", enabled: true,
                accounts: [
                    account("claude-a.json", email: "a@example.com"),
                    CLIProxyHubAccount(
                        id: "codex-b.json", authIndex: "7", provider: .codex, email: "b@example.com",
                        chatgptAccountID: "account-b", planType: "plus"
                    )
                ]
            )
        ])

        try store.save(config)

        XCTAssertNotNil(files.files[path])
        XCTAssertEqual(try store.load(), config)
    }

    func testSavingAccountsReplacesOnlyThatHubsCache() throws {
        let files = FakeFiles()
        let store = CLIProxyHubConfigStore(files: files)
        try store.save(CLIProxyHubConfig(hubs: [
            .init(id: "one", label: nil, url: "https://one.example", managementKey: "k1", enabled: true,
                  accounts: [account("old.json")]),
            .init(id: "two", label: "Two", url: "https://two.example", managementKey: "k2", enabled: false,
                  accounts: [account("kept.json")])
        ]))

        try store.saveAccounts([account("new.json", email: "n@example.com")], hubID: "one")

        let hubs = try store.load().hubs
        XCTAssertEqual(hubs.map(\.accounts), [[account("new.json", email: "n@example.com")], [account("kept.json")]])
        XCTAssertEqual(hubs.map(\.managementKey), ["k1", "k2"])
        XCTAssertEqual(hubs.map(\.enabled), [true, false])
    }

    func testHandWrittenHubWithoutEnabledOrAccountsIsEnabledAndEmpty() throws {
        let files = FakeFiles([path: #"{"hubs": [{"id": "h", "url": "https://h.example", "managementKey": "k"}]}"#])
        let hub = try XCTUnwrap(CLIProxyHubConfigStore(files: files).load().hubs.first)
        XCTAssertTrue(hub.enabled)
        XCTAssertEqual(hub.accounts, [])
        XCTAssertNil(hub.label)
    }

    func testMalformedFileThrowsInsteadOfReadingAsEmpty() {
        let files = FakeFiles([path: "{not json"])
        XCTAssertThrowsError(try CLIProxyHubConfigStore(files: files).load())
    }
}
