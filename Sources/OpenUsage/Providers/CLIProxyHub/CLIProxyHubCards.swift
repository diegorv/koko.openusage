import Foundation

/// Builds the hub cards from the account lists cached in the hub config, so launch never waits on a
/// hub. Card ids are minted directly from the hub and account; the account registry
/// (`ProviderAccountsStore`) never sees them.
@MainActor
enum CLIProxyHubCards {
    static func cardID(hubID: String, accountID: String) -> String {
        ProviderAccountID.make(family: "claude", identityKey: "cliproxy:\(hubID):\(accountID)")
    }

    static func displayName(account: CLIProxyHubAccount, hub: CLIProxyHubConfig.Hub, hubURL: URL) -> String {
        let label = hub.label ?? hubURL.host ?? hub.id
        return "Claude: \(account.email ?? account.id) (Hub \(label))"
    }

    /// Reads the hub config off the main actor (a local file only) and builds the Claude hub cards. A
    /// config that can't be read is logged and yields no hub cards.
    static func loadClaudeRuntimes(
        store: CLIProxyHubConfigStore = CLIProxyHubConfigStore(),
        http: any HTTPClient = URLSessionHTTPClient(logsErrorBodies: false)
    ) async -> [CLIProxyClaudeRuntime] {
        let hubs: [CLIProxyHubConfig.Hub]
        do {
            hubs = try await loadOffMainActor { try store.load().hubs }
        } catch {
            AppLog.error(.config, "cliproxy hub config at \(CLIProxyHubConfigStore.path) is unreadable; no hub cards this launch: \(error.localizedDescription)")
            return []
        }
        return claudeRuntimes(hubs: hubs, http: http)
    }

    /// One card per cached Claude account of each enabled hub, all of a hub's cards sharing one session.
    /// The config can be hand-edited, so a repeated hub id or card id (ids are case-insensitive) keeps
    /// only its first entry: duplicate card ids would crash the data store at launch.
    static func claudeRuntimes(
        hubs: [CLIProxyHubConfig.Hub],
        http: any HTTPClient = URLSessionHTTPClient(logsErrorBodies: false)
    ) -> [CLIProxyClaudeRuntime] {
        var seenHubIDs: Set<String> = []
        var seenCardIDs: Set<String> = []
        return hubs.filter(\.enabled).flatMap { hub -> [CLIProxyClaudeRuntime] in
            guard seenHubIDs.insert(hub.id.lowercased()).inserted else {
                AppLog.error(.config, "cliproxy hub \(hub.id) is listed more than once; keeping the first")
                return []
            }
            guard let url = URL(string: hub.url), url.scheme != nil, url.host != nil else {
                AppLog.error(.config, "cliproxy hub \(hub.id) has an invalid URL; skipping its cards")
                return []
            }
            let session = CLIProxyHubSession(
                hubID: hub.id,
                client: CLIProxyHubClient(hubURL: url, managementKey: hub.managementKey, http: http)
            )
            return hub.accounts.filter { $0.provider == .claude }.compactMap { account in
                let id = cardID(hubID: hub.id, accountID: account.id)
                guard seenCardIDs.insert(id).inserted else {
                    AppLog.error(.config, "cliproxy hub \(hub.id) lists account \(account.id) more than once; keeping the first")
                    return nil
                }
                return CLIProxyClaudeRuntime(
                    provider: ClaudeProvider.makeProvider(
                        id: id,
                        displayName: displayName(account: account, hub: hub, hubURL: url)
                    ),
                    account: account,
                    session: session
                )
            }
        }
    }

    /// Hub cards are on when their hub is configured, not by credential detection. A card id this
    /// install has never seen is turned on once and marked known, so `NewProviderSeeder` never probes
    /// it; after that the user's toggle wins. A store with no known set yet is left for
    /// `NewProviderSeeder` to baseline.
    static func enableNewCards(_ cards: [ProviderRuntime], enablement: ProviderEnablementStore) {
        guard !enablement.knownIDs.isEmpty else { return }
        let ids = Set(cards.map(\.provider.id))
        let newIDs = ids.subtracting(enablement.knownIDs)
        guard !newIDs.isEmpty else { return }
        enablement.registerKnownProviders(newIDs)
        for id in newIDs.sorted() {
            AppLog.info(.config, "new hub card \(id): enabling")
            enablement.setEnabled(true, for: id)
        }
    }
}
