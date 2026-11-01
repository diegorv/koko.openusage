import Foundation

/// A card for an account held by a CLIProxyAPI hub. Its hub turns it on, never local detection, and it
/// shows limits only, never local spend.
@MainActor
protocol CLIProxyHubCard: ProviderRuntime {}

/// The hub rejected the account's upstream login. The hub owns the tokens, so only a re-login on the
/// hub fixes it.
enum CLIProxyHubAccountError: Error, LocalizedError, Equatable {
    case reloginRequired

    var errorDescription: String? {
        switch self {
        case .reloginRequired:
            "Re-login this account on the hub. Its sign-in there was rejected."
        }
    }
}
