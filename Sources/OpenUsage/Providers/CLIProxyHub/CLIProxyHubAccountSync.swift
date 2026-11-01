import Foundation

/// Refreshes each enabled hub's cached account list from its `auth-files`, after launch and off the
/// launch path. Cards are built from the cache, so a changed list shows from the next launch.
enum CLIProxyHubAccountSync {
    /// Hubs are synced one after another so the config's load/modify/save never races itself. A hub
    /// that fails keeps its old cache; the others still sync.
    ///
    /// Returns whether any hub's set of accounts changed (an account added, removed, or disabled on the
    /// hub) and was saved, which is when this launch's cards are out of date.
    @discardableResult
    static func run(
        store: CLIProxyHubConfigStore = CLIProxyHubConfigStore(),
        http: any HTTPClient = URLSessionHTTPClient(logsErrorBodies: false)
    ) async -> Bool {
        let hubs: [CLIProxyHubConfig.Hub]
        do {
            hubs = try await loadOffMainActor { try store.load().hubs }
        } catch {
            // The cards already log this load failure at error level.
            AppLog.warn(.config, "cliproxy hub config at \(CLIProxyHubConfigStore.path) is unreadable; hub accounts not synced: \(error.localizedDescription)")
            return false
        }
        var changed = false
        // A repeated hub id keeps its first enabled entry, as the cards do; `saveAccounts` writes that one.
        var seenHubIDs: Set<String> = []
        for hub in hubs where hub.enabled && seenHubIDs.insert(hub.id.lowercased()).inserted {
            // The cards log an invalid hub URL, so it is skipped here without a second line.
            guard let url = URL(string: hub.url), url.scheme != nil, url.host != nil else { continue }
            let client = CLIProxyHubClient(hubURL: url, managementKey: hub.managementKey, http: http)
            do {
                let accounts = try await client.listAccounts()
                guard accounts != hub.accounts else { continue }
                try await loadOffMainActor { try store.saveAccounts(accounts, hubID: hub.id) }
                AppLog.info(.config, "cliproxy hub \(hub.id): cached \(accounts.count) accounts; cards update on next launch")
                if accountSetChanged(cached: hub.accounts, fetched: accounts) { changed = true }
            } catch {
                AppLog.error(.config, "The hub could not list accounts. cliproxy hub \(hub.id) keeps its cached list: \(error.localizedDescription)")
            }
        }
        return changed
    }

    /// Cards are keyed by account id, so only an added or dropped id changes them. A reorder or a new
    /// email or plan on the same accounts does not.
    static func accountSetChanged(cached: [CLIProxyHubAccount], fetched: [CLIProxyHubAccount]) -> Bool {
        Set(cached.map(\.id)) != Set(fetched.map(\.id))
    }
}
