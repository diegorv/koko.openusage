import Foundation

/// One Claude account held by a CLIProxyAPI hub. It shows the live limits only and reads them through
/// the hub: no token refresh (the hub owns the tokens), no local log scans (they would count this Mac's
/// spend), no Desktop or Keychain reads, and no reset grants. See docs/providers/cliproxy-hub.md.
@MainActor
final class CLIProxyClaudeRuntime: CLIProxyHubCard {
    static let usageURL = URL(string: "https://api.anthropic.com/api/oauth/usage")!

    let provider: Provider
    let account: CLIProxyHubAccount
    let session: CLIProxyHubSession
    private let usageClient: ClaudeUsageClient
    private let now: @Sendable () -> Date
    /// Last successful limits, kept so a rate-limited refresh still shows them with a staleness note.
    private var lastGoodUsage: ClaudeMappedUsage?

    init(
        provider: Provider,
        account: CLIProxyHubAccount,
        session: CLIProxyHubSession,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.provider = provider
        self.account = account
        self.session = session
        self.usageClient = ClaudeUsageClient(
            httpClient: CLIProxyHubHTTPClient(session: session, authIndex: account.authIndex)
        )
        self.now = now
    }

    var widgetDescriptors: [WidgetDescriptor] {
        ClaudeProvider.limitDescriptors(provider: provider)
    }

    /// Hub cards are enabled by adding the hub, never by local credential detection.
    func hasLocalCredentials() async -> Bool { false }

    func refresh() async -> ProviderSnapshot {
        let response: HTTPResponse
        do {
            // The hub swaps the empty bearer for the account's real token.
            response = try await usageClient.sendUsageRequest(url: Self.usageURL, accessToken: "")
        } catch {
            return ProviderSnapshot.error(provider: provider, error: error)
        }
        if ProviderAuthRetry.isAuthFailure(response) {
            AppLog.warn(LogTag.plugin("cliproxy"), "\(provider.id): hub account login rejected (HTTP \(response.statusCode)); needs a re-login on the hub")
            return ProviderSnapshot.error(provider: provider, error: CLIProxyHubAccountError.reloginRequired)
        }
        if response.statusCode == 429 {
            let retryAfter = ClaudeUsageMapper.parseRetryAfterSeconds(response, now: now())
            AppLog.info(LogTag.plugin("cliproxy"), "\(provider.id): rate-limited (serving \(lastGoodUsage == nil ? "badge" : "last-good usage"))")
            return snapshot(rateLimitedUsage(retryAfterSeconds: retryAfter))
        }
        do {
            let mapped = try ClaudeUsageMapper.mapUsageResponse(response, credentials: ClaudeOAuth(), now: now())
            lastGoodUsage = mapped
            return snapshot(mapped)
        } catch {
            return ProviderSnapshot.error(provider: provider, error: error)
        }
    }

    private func rateLimitedUsage(retryAfterSeconds: Int?) -> ClaudeMappedUsage {
        guard var mapped = lastGoodUsage else {
            return ClaudeUsageMapper.rateLimitedUsage(credentials: ClaudeOAuth(), retryAfterSeconds: retryAfterSeconds)
        }
        mapped.lines.append(ClaudeUsageMapper.rateLimitedNote(retryAfterSeconds: retryAfterSeconds))
        mapped.warning = ClaudeUsageMapper.rateLimitedWarning(retryAfterSeconds: retryAfterSeconds)
        return mapped
    }

    private func snapshot(_ mapped: ClaudeMappedUsage) -> ProviderSnapshot {
        var lines = mapped.lines
        MetricLine.appendNoDataIfNeeded(&lines)
        return ProviderSnapshot.make(
            provider: provider, plan: mapped.plan, lines: lines, refreshedAt: now(), warning: mapped.warning
        )
    }
}
