import XCTest
@testable import OpenUsage

/// Fixtures follow the CLIProxyAPI management contract in docs/research/cliproxy-hub-plan.md
/// ("Hub contract"): `GET auth-files` and the `POST api-call` envelope. The `auth-files` entries carry
/// the fields CLIProxyAPI's `buildAuthFileEntry` emits (internal/api/handlers/management/auth_files.go).
final class CLIProxyHubClientTests: XCTestCase {
    private static let key = "hub-mgmt-SECRET-key-0123456789"

    private static let authFiles = """
    {"observed_at": "2026-10-30T12:00:00Z", "files": [
      {"id": "claude-a.json", "auth_index": "a1b2c3", "name": "claude-a.json", "type": "claude", "provider": "claude",
       "label": "a@example.com", "status": "active", "status_message": "", "disabled": false, "unavailable": false,
       "runtime_only": false, "source": "file", "size": 512, "email": "a@example.com", "cooldowns": null},
      {"id": "codex-b.json", "auth_index": "d4e5f6", "name": "codex-b.json", "type": "codex", "provider": "codex",
       "label": "b@example.com", "status": "active", "status_message": "", "disabled": false, "unavailable": false,
       "runtime_only": false, "source": "file", "size": 2048, "email": "b@example.com",
       "id_token": {"chatgpt_account_id": "account-b", "plan_type": "plus"}, "cooldowns": null},
      {"id": "claude-off.json", "auth_index": "off1", "name": "claude-off.json", "type": "claude", "provider": "claude",
       "status": "disabled", "disabled": true, "email": "off@example.com"},
      {"id": "gemini-c.json", "auth_index": "g1", "name": "gemini-c.json", "type": "gemini", "provider": "gemini",
       "status": "active", "disabled": false, "email": "c@example.com"},
      {"id": "codex-n.json", "auth_index": 7, "name": "codex-n.json", "type": "codex", "status": "active", "disabled": false}
    ]}
    """

    private func makeHub(
        _ url: String = "https://hub.example.ts.net",
        handler: @escaping @Sendable (HTTPRequest) async throws -> HTTPResponse
    ) -> (CLIProxyHubClient, RoutingHTTPClient) {
        let http = RoutingHTTPClient(handler: handler)
        return (CLIProxyHubClient(hubURL: URL(string: url)!, managementKey: Self.key, http: http), http)
    }

    private static func json(_ text: String, status: Int = 200) -> HTTPResponse {
        HTTPResponse(statusCode: status, headers: ["content-type": "application/json"], body: Data(text.utf8))
    }

    /// An `api-call` envelope whose `body` is the upstream payload as a JSON string.
    private static func envelope(status: Int = 200, header: [String: Any] = [:], body: String) throws -> HTTPResponse {
        let object: [String: Any] = ["status_code": status, "header": header, "body": body]
        return HTTPResponse(statusCode: 200, headers: [:], body: try JSONSerialization.data(withJSONObject: object))
    }

    // MARK: - Management calls

    func testManagementCallsKeepAPathPrefixAndSendTheKey() async throws {
        for base in ["https://hub.example.ts.net/proxy", "https://hub.example.ts.net/proxy/"] {
            let (hub, http) = makeHub(base) { _ in Self.json(Self.authFiles) }
            _ = try await hub.listAccounts()

            let request = try XCTUnwrap(http.requests.first)
            XCTAssertEqual(request.url.absoluteString, "https://hub.example.ts.net/proxy/v0/management/auth-files")
            XCTAssertEqual(request.method, "GET")
            XCTAssertEqual(request.headers["Authorization"], "Bearer \(Self.key)")
            XCTAssertEqual(request.timeout, 15)
        }
    }

    func testAuthFilesKeepsOnlyEnabledClaudeAndCodexAccounts() async throws {
        let (hub, _) = makeHub { _ in Self.json(Self.authFiles) }
        let accounts = try await hub.listAccounts()

        XCTAssertEqual(accounts, [
            CLIProxyHubAccount(id: "claude-a.json", authIndex: "a1b2c3", provider: .claude, email: "a@example.com"),
            CLIProxyHubAccount(
                id: "codex-b.json", authIndex: "d4e5f6", provider: .codex, email: "b@example.com",
                chatgptAccountID: "account-b", planType: "plus"
            ),
            CLIProxyHubAccount(id: "codex-n.json", authIndex: "7", provider: .codex)
        ])
    }

    func testDiskFallbackEntriesWithoutAnIDAreCountedInTheWarning() async throws {
        // CLIProxyAPI's `listAuthFilesFromDisk` emits `name`/`type` but no `id` or `auth_index`.
        let disk = #"{"files": [{"name": "claude-d.json", "type": "claude", "email": "d@example.com", "size": 10}]}"#
        let (hub, _) = makeHub { _ in Self.json(disk) }
        let log = try await captureLog {
            let accounts = try await hub.listAccounts()
            XCTAssertEqual(accounts, [])
        }
        XCTAssertTrue(log.contains("skipped 1 entries"), log)
    }

    func testInvalidOrMissingKeyIsReportedAsBadKey() async {
        let (hub, _) = makeHub { _ in Self.json(#"{"error":"invalid management key"}"#, status: 401) }
        await assertThrows(CLIProxyHubError.badKey) { _ = try await hub.listAccounts() }
    }

    func testForbiddenManagementIsReportedAsAccessDenied() async {
        // CLIProxyAPI sends 403 for "remote management disabled", "remote management key not set" and
        // an IP ban after failed attempts: none of them mean the key is wrong.
        let (hub, _) = makeHub { _ in Self.json(#"{"error":"remote management disabled"}"#, status: 403) }
        await assertThrows(CLIProxyHubError.accessDenied) { _ = try await hub.listAccounts() }
    }

    func testDefaultTransportNeverLogsErrorBodies() throws {
        let hub = CLIProxyHubClient(hubURL: URL(string: "https://hub.example.ts.net")!, managementKey: Self.key)
        let http = try XCTUnwrap(hub.http as? URLSessionHTTPClient)
        XCTAssertFalse(http.logsErrorBodies)
    }

    func testErrorsMapToTheirCategories() {
        let cases: [(CLIProxyHubError, ErrorCategory)] = [
            (.unreachable, .network),
            (.timeout, .network),
            (.untrustedCertificate, .network),
            (.httpStatus(404), .http4xx),
            (.httpStatus(502), .http5xx),
            (.badKey, .authInvalid),
            (.accessDenied, .authInvalid),
            (.invalidResponse, .decoding)
        ]
        for (error, expected) in cases {
            XCTAssertEqual(error.errorCategory, expected, "\(error)")
        }
    }

    func testClientErrorCopyPointsAtTheHubNotARetry() throws {
        let clientError = try XCTUnwrap(CLIProxyHubError.httpStatus(404).errorDescription)
        XCTAssertTrue(clientError.contains("HTTP 404"), clientError)
        XCTAssertFalse(clientError.contains("Try again later"), clientError)
        XCTAssertTrue(try XCTUnwrap(CLIProxyHubError.httpStatus(502).errorDescription).contains("Try again later"))
    }

    func testManagementHTTPErrorCarriesTheStatus() async {
        let (hub, _) = makeHub { _ in Self.json("bad gateway", status: 502) }
        await assertThrows(CLIProxyHubError.httpStatus(502)) { _ = try await hub.listAccounts() }
    }

    func testTransportFailuresAreCategorized() async {
        let cases: [(URLError.Code, CLIProxyHubError)] = [
            (.timedOut, .timeout),
            (.serverCertificateUntrusted, .untrustedCertificate),
            (.serverCertificateHasUnknownRoot, .untrustedCertificate),
            (.cannotConnectToHost, .unreachable),
            (.cannotFindHost, .unreachable)
        ]
        for (code, expected) in cases {
            let (hub, _) = makeHub { _ in throw URLError(code) }
            await assertThrows(expected) { _ = try await hub.listAccounts() }
        }
    }

    func testUnreadableEnvelopeIsInvalidResponse() async {
        let (hub, _) = makeHub { _ in Self.json("<html>not json</html>") }
        await assertThrows(CLIProxyHubError.invalidResponse) {
            _ = try await hub.apiCall(authIndex: "a1", request: HTTPRequest(method: "GET", url: URL(string: "https://x.test")!))
        }
    }

    // MARK: - Transport adapter

    func testAdapterSendsTheUpstreamRequestAsAnAPICall() async throws {
        let (hub, http) = makeHub("https://hub.example.ts.net/proxy") { _ in try Self.envelope(body: "{}") }
        let adapter = CLIProxyHubHTTPClient(session: CLIProxyHubSession(hubID: "hub", client: hub), authIndex: "a1b2c3")

        _ = try await adapter.send(HTTPRequest(
            method: "POST",
            url: URL(string: "https://api.anthropic.com/api/oauth/usage")!,
            headers: ["authorization": "Bearer real-upstream-token", "anthropic-beta": "oauth-2025-04-20"],
            body: Data(#"{"a":1}"#.utf8),
            timeout: 10
        ))

        let request = try XCTUnwrap(http.requests.first)
        XCTAssertEqual(request.url.absoluteString, "https://hub.example.ts.net/proxy/v0/management/api-call")
        XCTAssertEqual(request.method, "POST")
        XCTAssertEqual(request.headers["Authorization"], "Bearer \(Self.key)")
        XCTAssertEqual(request.timeout, 15)

        let bodyData = try XCTUnwrap(request.body)
        XCTAssertFalse(String(decoding: bodyData, as: UTF8.self).contains("real-upstream-token"))
        let payload = try XCTUnwrap(try JSONSerialization.jsonObject(with: bodyData) as? [String: Any])
        XCTAssertEqual(payload["auth_index"] as? String, "a1b2c3")
        XCTAssertEqual(payload["method"] as? String, "POST")
        XCTAssertEqual(payload["url"] as? String, "https://api.anthropic.com/api/oauth/usage")
        XCTAssertEqual(payload["data"] as? String, #"{"a":1}"#)
        let header = try XCTUnwrap(payload["header"] as? [String: String])
        XCTAssertEqual(header, ["Authorization": "Bearer $TOKEN$", "anthropic-beta": "oauth-2025-04-20"])
    }

    func testAdapterOmitsDataWhenTheRequestHasNoBody() async throws {
        let (hub, http) = makeHub { _ in try Self.envelope(body: "{}") }
        _ = try await CLIProxyHubHTTPClient(session: CLIProxyHubSession(hubID: "hub", client: hub), authIndex: "a1")
            .send(HTTPRequest(method: "GET", url: URL(string: "https://chatgpt.com/backend-api/wham/usage")!))

        let payload = try XCTUnwrap(try JSONSerialization.jsonObject(with: XCTUnwrap(http.requests.first?.body)) as? [String: Any])
        XCTAssertNil(payload["data"])
        XCTAssertEqual(payload["header"] as? [String: String], ["Authorization": "Bearer $TOKEN$"])
    }

    func testEnvelopeIsUnwrappedWithItsHeaders() async throws {
        let (hub, _) = makeHub { _ in
            try Self.envelope(
                header: ["Content-Type": ["application/json"], "X-Codex-Primary-Used-Percent": "12"],
                body: #"{"ok":true}"#
            )
        }
        let response = try await CLIProxyHubHTTPClient(session: CLIProxyHubSession(hubID: "hub", client: hub), authIndex: "a1")
            .send(HTTPRequest(method: "GET", url: URL(string: "https://x.test")!))

        XCTAssertEqual(response.statusCode, 200)
        XCTAssertEqual(response.header("Content-Type"), "application/json")
        XCTAssertEqual(response.header("x-codex-primary-used-percent"), "12")
        XCTAssertEqual(String(decoding: response.body, as: UTF8.self), #"{"ok":true}"#)
    }

    func testNonTwoXXEnvelopeComesBackAsTheUpstreamResponse() async throws {
        let (hub, _) = makeHub { _ in
            try Self.envelope(status: 429, header: ["Retry-After": ["30"]], body: #"{"error":"rate_limited"}"#)
        }
        let response = try await CLIProxyHubHTTPClient(session: CLIProxyHubSession(hubID: "hub", client: hub), authIndex: "a1")
            .send(HTTPRequest(method: "GET", url: URL(string: "https://x.test")!))

        XCTAssertEqual(response.statusCode, 429)
        XCTAssertEqual(response.header("retry-after"), "30")
        XCTAssertEqual(String(decoding: response.body, as: UTF8.self), #"{"error":"rate_limited"}"#)
    }

    func testDoubleEncodedAndObjectBodiesUnwrapToTheSameJSON() async throws {
        let bodies = [
            #"{"status_code":200,"header":{},"body":"\"{\\\"ok\\\":true}\""}"#,
            #"{"status_code":200,"header":{},"body":{"ok":true}}"#
        ]
        for raw in bodies {
            let (hub, _) = makeHub { _ in Self.json(raw) }
            let response = try await CLIProxyHubHTTPClient(session: CLIProxyHubSession(hubID: "hub", client: hub), authIndex: "a1")
                .send(HTTPRequest(method: "GET", url: URL(string: "https://x.test")!))
            let object = try XCTUnwrap(ProviderParse.jsonObject(response.body), raw)
            XCTAssertEqual(object["ok"] as? Bool, true, raw)
        }
    }

    // MARK: - Redaction

    func testKeyBodiesAndHeadersNeverReachErrorsOrLogs() async throws {
        let echo = #"{"error":"bad key \#(Self.key)","detail":"body-marker"}"#
        let log = try await captureLog {
            for status in [401, 500] {
                let (hub, _) = makeHub { _ in Self.json(echo, status: status) }
                do {
                    _ = try await CLIProxyHubHTTPClient(session: CLIProxyHubSession(hubID: "hub", client: hub), authIndex: "a1").send(HTTPRequest(
                        method: "GET", url: URL(string: "https://x.test")!,
                        headers: ["Authorization": "Bearer header-marker"], body: Data("request-marker".utf8)
                    ))
                    XCTFail("expected an error for HTTP \(status)")
                } catch {
                    for text in [error.localizedDescription, String(describing: error), String(reflecting: error)] {
                        XCTAssertFalse(text.contains(Self.key), text)
                        XCTAssertFalse(text.contains("marker"), text)
                    }
                }
            }
        }

        let errors: [CLIProxyHubError] = [
            .unreachable, .timeout, .httpStatus(404), .httpStatus(502), .badKey, .accessDenied, .untrustedCertificate, .invalidResponse
        ]
        for error in errors {
            let text = try XCTUnwrap(error.errorDescription)
            XCTAssertFalse(text.isEmpty)
            XCTAssertFalse(text.contains(Self.key), text)
        }

        XCTAssertTrue(log.contains("cliproxy"), "the failures should be logged: \(log)")
        XCTAssertFalse(log.contains(Self.key), log)
        XCTAssertFalse(log.contains("marker"), log)
    }

    // MARK: - Parity with the local providers

    func testUnwrappedClaudeBodyMapsToTheSameLinesAsTheLocalFixture() async throws {
        let body = """
        {
          "five_hour": { "utilization": 10, "resets_at": "2099-01-01T00:00:00.000Z" },
          "seven_day": { "utilization": 20, "resets_at": "2099-01-01T00:00:00.000Z" },
          "seven_day_sonnet": { "utilization": 5, "resets_at": "2099-01-01T00:00:00.000Z" },
          "extra_usage": { "is_enabled": true, "used_credits": 500, "monthly_limit": 1000 }
        }
        """
        let credentials = ClaudeOAuth(subscriptionType: "max", rateLimitTier: "claude_max_subscription_20x")
        let local = try ClaudeUsageMapper.mapUsageResponse(Self.json(body), credentials: credentials)

        let (hub, _) = makeHub { _ in try Self.envelope(header: ["Content-Type": ["application/json"]], body: body) }
        let config = ClaudeOAuthConfig(
            usageURL: URL(string: "https://api.anthropic.com/api/oauth/usage")!,
            refreshURL: URL(string: "https://platform.claude.com/v1/oauth/token")!,
            clientID: "client"
        )
        let response = try await ClaudeUsageClient(httpClient: CLIProxyHubHTTPClient(session: CLIProxyHubSession(hubID: "hub", client: hub), authIndex: "a1"))
            .fetchUsage(accessToken: "unused", config: config)
        let viaHub = try ClaudeUsageMapper.mapUsageResponse(response, credentials: credentials)

        XCTAssertFalse(local.lines.isEmpty)
        XCTAssertEqual(viaHub, local)
    }

    func testUnwrappedCodexBodyMapsToTheSameLinesAsTheLocalFixture() async throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let body = """
        {
          "plan_type": "plus",
          "rate_limit": {
            "primary_window": { "used_percent": 1, "limit_window_seconds": 18000, "reset_after_seconds": 60 },
            "secondary_window": { "used_percent": 30, "limit_window_seconds": 604800, "reset_after_seconds": 600 }
          },
          "credits": { "balance": 12.5 }
        }
        """
        let local = try CodexUsageMapper.mapUsageResponse(Self.json(body), now: now)

        let (hub, _) = makeHub { _ in try Self.envelope(body: body) }
        let response = try await CodexUsageClient(http: CLIProxyHubHTTPClient(session: CLIProxyHubSession(hubID: "hub", client: hub), authIndex: "d4e5f6"))
            .fetchUsage(accessToken: "unused", accountID: "account-b")
        let viaHub = try CodexUsageMapper.mapUsageResponse(response, now: now)

        XCTAssertFalse(local.lines.isEmpty)
        XCTAssertEqual(viaHub, local)
    }

    // MARK: - Helpers

    /// Runs `body` with `AppLog` writing to a temporary file, and returns what was logged.
    private func captureLog(_ body: () async throws -> Void) async throws -> String {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("OpenUsageTests.CLIProxyHub.\(UUID().uuidString)", isDirectory: true)
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

    private func assertThrows(
        _ expected: CLIProxyHubError,
        file: StaticString = #filePath,
        line: UInt = #line,
        _ body: () async throws -> Void
    ) async {
        do {
            try await body()
            XCTFail("expected \(expected)", file: file, line: line)
        } catch let error as CLIProxyHubError {
            XCTAssertEqual(error, expected, file: file, line: line)
        } catch {
            XCTFail("unexpected \(error)", file: file, line: line)
        }
    }
}
