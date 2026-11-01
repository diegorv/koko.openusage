import Foundation
import Observation

/// Backs the Settings "CLIProxyAPI Hubs" section: adds, disables and removes hubs in the hub config.
/// Cards are built at launch, so every save raises the relaunch notice.
@MainActor
@Observable
final class CLIProxyHubSettings {
    private(set) var hubs: [CLIProxyHubConfig.Hub] = []
    /// Set when the config file can't be read or parsed. Saving is refused meanwhile, since writing
    /// would replace the user's file (and every hub in it) with only what the form knows.
    private(set) var loadError: String?
    /// The last add, disable or remove that failed, in friendly copy.
    private(set) var actionError: String?

    @ObservationIgnored private let store: CLIProxyHubConfigStore
    @ObservationIgnored private let notice: CLIProxyHubRelaunchNotice
    @ObservationIgnored private let syncAccounts: @Sendable () async -> Void
    @ObservationIgnored private var isSyncing = false
    @ObservationIgnored private var syncAgain = false

    /// `syncAccounts` caches a new hub's account list right after a save, so a single relaunch shows
    /// its cards instead of a second "Hub Accounts Changed" round.
    init(
        store: CLIProxyHubConfigStore = CLIProxyHubConfigStore(),
        notice: CLIProxyHubRelaunchNotice,
        syncAccounts: @escaping @Sendable () async -> Void = { _ = await CLIProxyHubAccountSync.run() }
    ) {
        self.store = store
        self.notice = notice
        self.syncAccounts = syncAccounts
    }

    func reload() {
        actionError = nil
        do {
            hubs = try store.load().hubs
            loadError = nil
        } catch {
            hubs = []
            loadError = "OpenUsage couldn't read \(CLIProxyHubConfigStore.path). Fix or remove the file, then reopen Settings."
            AppLog.error(.config, "cliproxy hub config at \(CLIProxyHubConfigStore.path) is unreadable in Settings: \(error.localizedDescription)")
        }
    }

    /// Adds a hub, or updates the saved hub with the same URL (keeping its id, state and cached
    /// accounts). A blank label is stored as none, so cards fall back to the host.
    func addHub(url rawURL: String, managementKey rawKey: String, label rawLabel: String) {
        let urlText = Self.normalizedURL(rawURL)
        let key = rawKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let labelText = rawLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        let label = labelText.isEmpty ? nil : labelText
        guard let url = URL(string: urlText), url.scheme != nil, url.host != nil else {
            actionError = "Enter the hub's full URL, like https://hub.example.ts.net."
            return
        }
        guard !key.isEmpty else { return }
        update { hubs in
            if let index = hubs.firstIndex(where: { Self.normalizedURL($0.url).caseInsensitiveCompare(urlText) == .orderedSame }) {
                hubs[index].managementKey = key
                hubs[index].label = label
            } else {
                hubs.append(.init(
                    id: Self.hubID(for: url, existing: hubs.map(\.id)), label: label, url: urlText,
                    managementKey: key, enabled: true, accounts: []
                ))
            }
        }
    }

    func clearActionError() {
        actionError = nil
    }

    func setEnabled(_ enabled: Bool, hubID: String) {
        update { hubs in
            for index in hubs.indices where hubs[index].id == hubID { hubs[index].enabled = enabled }
        }
    }

    func remove(hubID: String) {
        update { hubs in hubs.removeAll { $0.id == hubID } }
    }

    /// `cliproxy-<host-slug>`, then `-2`, `-3`, … while the id is taken (ids are case-insensitive).
    static func hubID(for url: URL, existing: [String]) -> String {
        let host = (url.host ?? "").lowercased()
        let slug = host.split(whereSeparator: { !($0.isASCII && ($0.isLetter || $0.isNumber)) }).joined(separator: "-")
        let base = "cliproxy-\(slug)"
        let taken = Set(existing.map { $0.lowercased() })
        guard taken.contains(base) else { return base }
        var suffix = 2
        while taken.contains("\(base)-\(suffix)") { suffix += 1 }
        return "\(base)-\(suffix)"
    }

    private static func normalizedURL(_ text: String) -> String {
        var url = text.trimmingCharacters(in: .whitespacesAndNewlines)
        while url.hasSuffix("/") { url.removeLast() }
        return url
    }

    /// Re-reads the file before changing it, so the background account sync's latest cache is kept.
    private func update(_ change: (inout [CLIProxyHubConfig.Hub]) -> Void) {
        let saved = store.exclusively {
            reload()
            guard loadError == nil else { return false }
            var config = CLIProxyHubConfig(hubs: hubs)
            change(&config.hubs)
            do {
                try store.save(config)
            } catch {
                actionError = "OpenUsage couldn't save the hub settings."
                AppLog.error(.config, "cliproxy hub config save failed: \(error.localizedDescription)")
                return false
            }
            hubs = config.hubs
            return true
        }
        guard saved else { return }
        actionError = nil
        notice.markChanged()
        requestSync()
    }

    /// One sync at a time, like the account sync's own hub-by-hub loop. A save during a sync asks for
    /// one more pass after it, so the newest hubs are still synced.
    private func requestSync() {
        guard !isSyncing else {
            syncAgain = true
            return
        }
        isSyncing = true
        let syncAccounts = syncAccounts
        Task {
            repeat {
                syncAgain = false
                await syncAccounts()
            } while syncAgain
            isSyncing = false
        }
    }
}
