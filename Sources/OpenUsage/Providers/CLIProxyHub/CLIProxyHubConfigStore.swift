import Foundation

/// The user's CLIProxyAPI hubs and, per hub, the account list last read from its `auth-files`. Hub
/// cards are built from that cached list at launch, so launch never waits on a hub.
struct CLIProxyHubConfig: Codable, Equatable, Sendable {
    struct Hub: Codable, Equatable, Sendable {
        var id: String
        var label: String?
        var url: String
        var managementKey: String
        var enabled: Bool
        var accounts: [CLIProxyHubAccount]

        init(
            id: String, label: String?, url: String, managementKey: String, enabled: Bool,
            accounts: [CLIProxyHubAccount]
        ) {
            self.id = id
            self.label = label
            self.url = url
            self.managementKey = managementKey
            self.enabled = enabled
            self.accounts = accounts
        }

        /// A hand-written hub may leave out `enabled` (on) and `accounts` (none cached yet).
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(String.self, forKey: .id)
            label = try container.decodeIfPresent(String.self, forKey: .label)
            url = try container.decode(String.self, forKey: .url)
            managementKey = try container.decode(String.self, forKey: .managementKey)
            enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
            accounts = try container.decodeIfPresent([CLIProxyHubAccount].self, forKey: .accounts) ?? []
        }
    }

    var hubs: [Hub]
}

/// Reads and writes `~/.config/openusage/cliproxy.json`, a plain config file like the user API-key
/// files (`UserAPIKeyStore`). The file holds management keys, so it is written owner-only by
/// `LocalTextFileAccessor`.
struct CLIProxyHubConfigStore: Sendable {
    static let path = "~/.config/openusage/cliproxy.json"

    var files: TextFileAccessing = LocalTextFileAccessor()

    /// A missing file is no hubs. An unreadable or malformed file throws, so the caller logs it
    /// instead of silently dropping every hub card.
    func load() throws -> CLIProxyHubConfig {
        guard let text = try files.readTextIfPresent(Self.path) else { return CLIProxyHubConfig(hubs: []) }
        return try JSONDecoder().decode(CLIProxyHubConfig.self, from: Data(text.utf8))
    }

    func save(_ config: CLIProxyHubConfig) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try files.writeText(Self.path, String(decoding: try encoder.encode(config), as: UTF8.self))
    }

    /// Settings writes the file on the main actor and the account sync writes it off it. A
    /// load/modify/save run inside `exclusively` can't interleave with another one, so neither
    /// overwrites the other's change. Not reentrant.
    private static let lock = NSLock()

    func exclusively<Result>(_ body: () throws -> Result) rethrows -> Result {
        try Self.lock.withLock(body)
    }

    /// Replaces one hub's cached account list and leaves every other hub as it is. A repeated hub id
    /// resolves to its first enabled entry (case-insensitive), the same one the cards and the sync use.
    func saveAccounts(_ accounts: [CLIProxyHubAccount], hubID: String) throws {
        try exclusively {
            var config = try load()
            let id = hubID.lowercased()
            guard let index = config.hubs.firstIndex(where: { $0.enabled && $0.id.lowercased() == id }) else {
                AppLog.warn(.config, "cliproxy hub \(hubID) is no longer configured or enabled; its account list was not saved")
                return
            }
            config.hubs[index].accounts = accounts
            try save(config)
        }
    }
}
