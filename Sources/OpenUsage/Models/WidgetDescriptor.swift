import Foundation

/// A provider metric's identity and presentation template. Live provider lines supply the values;
/// `sample` carries stable display metadata such as title, icon, kind, and descriptor opt-ins.
struct WidgetDescriptor: Identifiable, Hashable {
    let id: String                 // "claude.session"
    let providerID: String
    let metricLabel: String
    let sample: WidgetData
    /// Whether this widget can be pinned to the menu-bar strip. False for tiles the tray can't render as
    /// a value — the Usage Trend chart — so the pin affordance never offers a pin that would read "0".
    var pinnable: Bool = true
    /// Stable scalar resources exported by `/v1/limits`. Empty for UI-only/history widgets.
    var limitResources: [LimitResourceDescriptor] = []
    /// Explicit aggregation semantics for this provider's normalized daily history. Exactly one
    /// descriptor carries it for every provider that exposes the shared spend tiles.
    var historyResource: UsageHistoryDescriptor? = nil
    /// The dashboard leaves this row out while no account has data for it, instead of a "No data" row.
    /// For a window the provider may stop reporting (Claude's five-hour Session), so it returns by
    /// itself when readings come back. See `WidgetDataStore.shownGroup`.
    var hidesWithoutData: Bool = false

    /// The metric's single display name.
    var title: String { sample.title }

    func hidingWithoutData() -> WidgetDescriptor {
        var copy = self
        copy.hidesWithoutData = true
        return copy
    }

    static func == (lhs: WidgetDescriptor, rhs: WidgetDescriptor) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
