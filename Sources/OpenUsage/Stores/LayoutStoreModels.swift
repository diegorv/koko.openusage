/// A provider and its placed (visible) widgets, split into Always Visible rows and On Demand rows
/// behind the dashboard's caret. Drives the grouped dashboard list.
struct ProviderGroup: Identifiable {
    let provider: Provider
    let alwaysShownWidgets: [PlacedWidget]
    let expandedWidgets: [PlacedWidget]
    /// The accounts folded into this card when a provider family has two or more enabled accounts
    /// (`provider` is then the family's base account under the family name). Empty for a normal card.
    var accounts: [MergedAccount] = []
    var id: String { provider.id }

    /// The provider ids whose data this card shows: every merged account, or just `provider`.
    var memberIDs: [String] { accounts.isEmpty ? [provider.id] : accounts.map(\.providerID) }

    /// The provider whose reset-claim service the card's resets popover uses. None on a merged card:
    /// its popover lists every account's credits, and one account's service would spend the wrong one.
    var resetClaimProviderID: String? { accounts.isEmpty ? provider.id : nil }

    /// Every visible widget in display order (always-shown first, then expanded). Used where the split
    /// doesn't matter — reorder id lists and the lifted drag preview.
    var widgets: [PlacedWidget] { alwaysShownWidgets + expandedWidgets }
    var hasExpandedMetrics: Bool { !expandedWidgets.isEmpty }
}

/// A provider and every metric it supports, in the provider's custom order, split between Always
/// Visible and On Demand. Drives the Customize screen and the menu-bar pin grouping.
struct ProviderMetrics: Identifiable {
    let provider: Provider
    let alwaysShownMetrics: [WidgetDescriptor]
    let expandedMetrics: [WidgetDescriptor]
    /// The accounts folded into this menu-bar item when its family is merged (see `ProviderGroup.accounts`).
    /// Empty for a normal provider.
    var accounts: [MergedAccount] = []
    var id: String { provider.id }

    init(provider: Provider, alwaysShownMetrics: [WidgetDescriptor], expandedMetrics: [WidgetDescriptor],
         accounts: [MergedAccount] = []) {
        self.provider = provider
        self.alwaysShownMetrics = alwaysShownMetrics
        self.expandedMetrics = expandedMetrics
        self.accounts = accounts
    }

    /// Convenience for callers that don't partition (e.g. tests): everything is always-shown.
    init(provider: Provider, metrics: [WidgetDescriptor]) {
        self.init(provider: provider, alwaysShownMetrics: metrics, expandedMetrics: [])
    }

    /// Every supported metric in custom order (always-shown first, then expanded).
    var metrics: [WidgetDescriptor] { alwaysShownMetrics + expandedMetrics }
}

/// One row in the Customize provider list (L1): the provider plus the derived bits the row renders —
/// whether it's enabled (the master toggle + Active/Inactive label), how many metrics it supports
/// (the badge), and how many are pinned. Drives `CustomizeProviderListView`. Unlike `ProviderMetrics`,
/// this includes disabled providers so they stay visible in the list.
struct ProviderRow: Identifiable {
    let provider: Provider
    let isEnabled: Bool
    let metricCount: Int
    var id: String { provider.id }
}

/// Tone for the transient in-Customize pill (`LayoutStore.customizationNotice`): green success or
/// orange denial.
enum CustomizationNoticeTone {
    case positive
    case notice
}

/// The message + tone carried by the Customize pill's `TransientNotice`, so its two fields clear together.
struct CustomizationNoticeContent {
    var message: String
    var tone: CustomizationNoticeTone
}
