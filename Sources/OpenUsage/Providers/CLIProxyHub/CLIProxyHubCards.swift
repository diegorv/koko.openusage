import Foundation

/// Builds the hub cards from the account lists cached in the hub config, so launch never waits on a
/// hub. Card ids are minted directly from the hub and account; the account registry
/// (`ProviderAccountsStore`) never sees them.
@MainActor
enum CLIProxyHubCards {
    /// The hub cards of every enabled hub, by family.
    struct Runtimes {
        var claude: [CLIProxyClaudeRuntime] = []
        var codex: [CLIProxyCodexRuntime] = []

        var all: [ProviderRuntime] { claude + codex }
    }

    static func cardID(family: CLIProxyHubAccount.Provider, hubID: String, accountID: String) -> String {
        ProviderAccountID.make(family: family.rawValue, identityKey: "cliproxy:\(hubID):\(accountID)")
    }

    static func displayName(account: CLIProxyHubAccount, hub: CLIProxyHubConfig.Hub, hubURL: URL) -> String {
        let label = hub.label ?? hubURL.host ?? hub.id
        let family = switch account.provider {
        case .claude: "Claude"
        case .codex: "Codex"
        }
        return "\(family): \(account.email ?? account.id) (Hub \(label))"
    }

    /// Reads the hub config off the main actor (a local file only) and builds the hub cards. A config
    /// that can't be read is logged and yields no hub cards.
    static func loadRuntimes(
        store: CLIProxyHubConfigStore = CLIProxyHubConfigStore(),
        http: any HTTPClient = URLSessionHTTPClient(logsErrorBodies: false)
    ) async -> Runtimes {
        let hubs: [CLIProxyHubConfig.Hub]
        do {
            hubs = try await loadOffMainActor { try store.load().hubs }
        } catch {
            AppLog.error(.config, "cliproxy hub config at \(CLIProxyHubConfigStore.path) is unreadable; no hub cards this launch: \(error.localizedDescription)")
            return Runtimes()
        }
        return runtimes(hubs: hubs, http: http)
    }

    /// One card per cached account of each enabled hub, all of a hub's cards (both families) sharing
    /// one session. The config can be hand-edited, so a repeated hub id or card id (ids are
    /// case-insensitive) keeps only its first entry: duplicate card ids would crash the data store at
    /// launch.
    static func runtimes(
        hubs: [CLIProxyHubConfig.Hub],
        http: any HTTPClient = URLSessionHTTPClient(logsErrorBodies: false)
    ) -> Runtimes {
        var result = Runtimes()
        var seenHubIDs: Set<String> = []
        var seenCardIDs: Set<String> = []
        for hub in hubs where hub.enabled {
            guard seenHubIDs.insert(hub.id.lowercased()).inserted else {
                AppLog.error(.config, "cliproxy hub \(hub.id) is listed more than once; keeping the first")
                continue
            }
            guard let url = URL(string: hub.url), url.scheme != nil, url.host != nil else {
                AppLog.error(.config, "cliproxy hub \(hub.id) has an invalid URL; skipping its cards")
                continue
            }
            let session = CLIProxyHubSession(
                hubID: hub.id,
                client: CLIProxyHubClient(hubURL: url, managementKey: hub.managementKey, http: http)
            )
            for account in hub.accounts {
                let id = cardID(family: account.provider, hubID: hub.id, accountID: account.id)
                guard seenCardIDs.insert(id).inserted else {
                    AppLog.error(.config, "cliproxy hub \(hub.id) lists account \(account.id) more than once; keeping the first")
                    continue
                }
                let name = displayName(account: account, hub: hub, hubURL: url)
                switch account.provider {
                case .claude:
                    result.claude.append(CLIProxyClaudeRuntime(
                        provider: ClaudeProvider.makeProvider(id: id, displayName: name),
                        account: account,
                        session: session
                    ))
                case .codex:
                    result.codex.append(CLIProxyCodexRuntime(
                        provider: CodexProvider.makeProvider(id: id, displayName: name),
                        account: account,
                        session: session
                    ))
                }
            }
        }
        return result
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
