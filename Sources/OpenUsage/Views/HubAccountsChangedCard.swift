import SwiftUI

/// Shown when the background hub sync saved a different set of hub accounts: cards are built at
/// launch, so the new accounts appear (and removed ones go) only after a relaunch.
struct HubAccountsChangedCard: View {
    let notice: CLIProxyHubRelaunchNotice

    var body: some View {
        DismissableHintCard(
            systemImage: "arrow.clockwise.circle",
            title: "Hub Accounts Changed",
            message: notice.relaunchFailed
                ? "koko.openusage couldn't relaunch itself. Quit and reopen it to show the hub's current accounts."
                : "Relaunch koko.openusage to show the hub's current accounts.",
            buttonTitle: "Relaunch",
            action: { notice.relaunch() },
            onDismiss: { withAnimation(Motion.spring) { notice.dismiss() } }
        )
    }
}
