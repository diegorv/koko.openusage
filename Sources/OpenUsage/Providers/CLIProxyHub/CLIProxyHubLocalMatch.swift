import Foundation

/// A local Claude or Codex card and the account it reads, as far as the launch account pass knows it.
/// Compared against the hub accounts so a hub card wins over the same account signed in on this Mac.
struct CLIProxyHubLocalAccount: Equatable, Sendable {
    let cardID: String
    let family: CLIProxyHubAccount.Provider
    let email: String?
    var chatgptAccountID: String? = nil
}

extension ProviderAccountAssembly {
    /// Every local Claude and Codex card this launch builds, with its account. The plain `claude` and
    /// `codex` cards stand in when a family has no account cards; one whose account didn't resolve is
    /// left out, so it is never hidden.
    var localAccounts: [CLIProxyHubLocalAccount] {
        var accounts: [CLIProxyHubLocalAccount] = []
        if claudeCards.isEmpty {
            if let identity = identityKeysByCard["claude"] {
                accounts.append(CLIProxyHubLocalAccount(
                    cardID: "claude", family: .claude, email: claudeEmailsByUser[Self.userUUID(identity)]
                ))
            }
        } else {
            accounts += claudeCards.map { card in
                CLIProxyHubLocalAccount(
                    cardID: card.id, family: .claude,
                    email: card.swapAccount?.email.lowercased() ?? claudeEmailsByUser[Self.userUUID(card.identityKey)]
                )
            }
        }
        if codex.cards.isEmpty {
            if let accountID = identityKeysByCard["codex"] {
                accounts.append(CLIProxyHubLocalAccount(
                    cardID: "codex", family: .codex, email: codexDefaultEmail, chatgptAccountID: accountID
                ))
            }
        } else {
            accounts += codex.cards.map { card in
                CLIProxyHubLocalAccount(
                    cardID: card.id, family: .codex, email: card.identity.email,
                    chatgptAccountID: card.identity.accountID.nilIfEmpty
                )
            }
        }
        return accounts
    }
}

extension CLIProxyHubCards.Runtimes {
    var accounts: [CLIProxyHubAccount] { claude.map(\.account) + codex.map(\.account) }
}

extension CLIProxyHubCards {
    /// The local cards to leave out this launch: the hub card wins over the same account (owner
    /// decision), and the local card's spend history goes with it. Only enabled hubs build cards, so
    /// removing or disabling the hub brings the local card back on the next launch. Enablement and
    /// layout are left alone.
    static func hiddenLocalCardIDs(local: [CLIProxyHubLocalAccount], hub: Runtimes) -> Set<String> {
        let hubAccounts = hub.accounts
        var hidden: Set<String> = []
        for account in local where hubAccounts.contains(where: { matches(account, $0) }) {
            AppLog.info(.config, "local card \(account.cardID) hidden: the same account is on a hub")
            hidden.insert(account.cardID)
        }
        return hidden
    }

    /// Claude matches by email. Codex matches by ChatGPT account id when both sides know it, and by
    /// email otherwise: the same email in another workspace is a different usage pool. Seats of one
    /// ChatGPT Team workspace share the account id, so when both sides also have an email it must
    /// agree (owner decision).
    static func matches(_ local: CLIProxyHubLocalAccount, _ hub: CLIProxyHubAccount) -> Bool {
        guard local.family == hub.provider else { return false }
        if local.family == .codex, let localID = normalized(local.chatgptAccountID),
           let hubID = normalized(hub.chatgptAccountID) {
            guard localID == hubID else { return false }
            guard let localEmail = normalized(local.email), let hubEmail = normalized(hub.email) else { return true }
            return localEmail == hubEmail
        }
        guard let localEmail = normalized(local.email) else { return false }
        return localEmail == normalized(hub.email)
    }

    private static func normalized(_ value: String?) -> String? {
        value?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty?.lowercased()
    }
}
