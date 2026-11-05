import Foundation

/// One Codex account held by a CLIProxyAPI hub. It shows the live limits and ChatGPT's reported token counts,
/// read through the hub: no token refresh (the hub owns the tokens), no local log scans (they would count this Mac's
/// spend), no auth.json or Keychain reads, and no reset-credit claims. See docs/providers/cliproxy-hub.md.
@MainActor
final class CLIProxyCodexRuntime: CLIProxyHubCard {
    let provider: Provider
    let account: CLIProxyHubAccount
    let session: CLIProxyHubSession
    private let http: CLIProxyHubHTTPClient
    private let now: @Sendable () -> Date
    /// ChatGPT's daily token counts, kept between reads so the rows stay up while the report is re-read.
    private var tokenHistory: DailyUsageSeries?
    private var tokenHistoryReadAt: Date?
    private static let tokenHistoryInterval: TimeInterval = 3600
    private static let tokenReportURL = URL(string: "https://chatgpt.com/backend-api/wham/analytics/daily-workspace-usage-counts")!

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
        CodexProvider.limitDescriptors(provider: provider) + WidgetDescriptor.spendTiles(provider: provider)
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
            // A zero balance says nothing, so its row hides until there are credits.
            lines.removeAll { line in
                guard line.label == "Credits", case .values(_, let values, _, _, _, _) = line else { return false }
                return values.allSatisfy { $0.number == 0 }
            }
            await loadTokenHistoryIfNeeded()
            if let tokenHistory {
                SpendTileMapper.appendTokenUsage(tokenHistory, to: &lines, now: now(), estimated: false)
            }
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

    private func loadTokenHistoryIfNeeded() async {
        let current = now()
        if let tokenHistoryReadAt, current.timeIntervalSince(tokenHistoryReadAt) < Self.tokenHistoryInterval { return }
        do {
            let response = try await http.send(tokenReportRequest(now: current))
            guard (200..<300).contains(response.statusCode), let series = Self.parseTokenReport(response.body) else {
                AppLog.warn(LogTag.plugin("cliproxy"), "\(provider.id): token report unusable (HTTP \(response.statusCode))")
                return
            }
            tokenHistory = series
            tokenHistoryReadAt = current
        } catch {
            AppLog.warn(LogTag.plugin("cliproxy"), "\(provider.id): token report failed: \(error)")
        }
    }

    private func tokenReportRequest(now: Date) -> HTTPRequest {
        let start = now.addingTimeInterval(-29 * 86_400)
        var url = Self.tokenReportURL
        url.append(queryItems: [
            URLQueryItem(name: "start_date", value: start.formatted(.iso8601.year().month().day())),
            URLQueryItem(name: "end_date", value: now.formatted(.iso8601.year().month().day())),
            URLQueryItem(name: "group_by", value: "day"),
            URLQueryItem(name: "workspace_user", value: "true")
        ])
        return HTTPRequest(method: "GET", url: url, headers: requestHeaders(), timeout: 10)
    }

    /// Daily token totals. A day without a token count has no tokens to show and is left out.
    private static func parseTokenReport(_ body: Data) -> DailyUsageSeries? {
        guard let records = ProviderParse.jsonObject(body)?["data"] as? [[String: Any]] else { return nil }
        var tokensByDay: [String: Int] = [:]
        for record in records {
            guard let date = record["date"] as? String, date.count >= 10,
                  let totals = record["totals"] as? [String: Any] else { return nil }
            guard let tokens = ProviderParse.number(totals["text_total_tokens"]) else { continue }
            tokensByDay[String(date.prefix(10)), default: 0] += Int(tokens)
        }
        return DailyUsageSeries(daily: tokensByDay.sorted { $0.key < $1.key }.map {
            DailyUsageEntry(date: $0.key, totalTokens: $0.value, costUSD: nil)
        })
    }

    /// The hub replaces `Authorization` with the account's token. The Codex desktop headers match what
    /// the hub's own Codex clients send.
    private func usageRequest() -> HTTPRequest {
        HTTPRequest(method: "GET", url: CodexUsageClient.usageURL, headers: requestHeaders(), timeout: 10)
    }

    private func requestHeaders() -> [String: String] {
        var headers = [
            "Accept": "application/json",
            "User-Agent": "OpenUsage",
            "OpenAI-Beta": "codex-1",
            "Originator": "Codex Desktop"
        ]
        if let accountID = account.chatgptAccountID, !accountID.isEmpty {
            headers["Chatgpt-Account-Id"] = accountID
        }
        return headers
    }
}
