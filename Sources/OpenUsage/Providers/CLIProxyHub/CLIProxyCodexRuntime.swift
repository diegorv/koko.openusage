import Foundation

/// One Codex account held by a CLIProxyAPI hub. It shows the live limits only and reads them through
/// the hub: no token refresh (the hub owns the tokens), no local log scans (they would count this Mac's
/// spend), no auth.json or Keychain reads, and no reset-credit claims. See docs/providers/cliproxy-hub.md.
@MainActor
final class CLIProxyCodexRuntime: CLIProxyHubCard {
    let provider: Provider
    let account: CLIProxyHubAccount
    let session: CLIProxyHubSession
    private let http: CLIProxyHubHTTPClient
    private let now: @Sendable () -> Date

    init(
        provider: Provider,
        account: CLIProxyHubAccount,
        session: CLIProxyHubSession,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.provider = provider
        self.account = account
        self.session = session
        self.http = CLIProxyHubHTTPClient(session: session, authIndex: account.authIndex)
        self.now = now
    }

    var widgetDescriptors: [WidgetDescriptor] {
        CodexProvider.limitDescriptors(provider: provider)
    }

    /// Hub cards are enabled by adding the hub, never by local credential detection.
    func hasLocalCredentials() async -> Bool { false }

    func refresh() async -> ProviderSnapshot {
        let response: HTTPResponse
        do {
            response = try await http.send(usageRequest())
        } catch {
            return ProviderSnapshot.error(provider: provider, error: error)
        }
        if ProviderAuthRetry.isAuthFailure(response) {
            AppLog.warn(LogTag.plugin("cliproxy"), "\(provider.id): hub account login rejected (HTTP \(response.statusCode)); needs a re-login on the hub")
            return ProviderSnapshot.error(provider: provider, error: CLIProxyHubAccountError.reloginRequired)
        }
        do {
            let mapped = try CodexUsageMapper.mapUsageResponse(response, now: now())
            var lines = mapped.lines
            MetricLine.appendNoDataIfNeeded(&lines)
            return ProviderSnapshot.make(
                provider: provider,
                plan: mapped.plan ?? CodexUsageMapper.formatCodexPlan(account.planType),
                lines: lines,
                refreshedAt: now()
            )
        } catch {
            return ProviderSnapshot.error(provider: provider, error: error)
        }
    }

    /// The hub replaces `Authorization` with the account's token. The Codex desktop headers match what
    /// the hub's own Codex clients send.
    private func usageRequest() -> HTTPRequest {
        var headers = [
            "Accept": "application/json",
            "User-Agent": "OpenUsage",
            "OpenAI-Beta": "codex-1",
            "Originator": "Codex Desktop"
        ]
        if let accountID = account.chatgptAccountID, !accountID.isEmpty {
            headers["Chatgpt-Account-Id"] = accountID
        }
        return HTTPRequest(method: "GET", url: CodexUsageClient.usageURL, headers: headers, timeout: 10)
    }
}
