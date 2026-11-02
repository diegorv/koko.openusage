import Foundation

extension WidgetDataStore {
    /// `group` as the dashboard and share card show it: without the rows whose descriptor
    /// `hidesWithoutData` and that have no data on this card (merged: no account has any).
    /// Re-applies `LayoutStore`'s rule that a card keeps an Always Visible row, and keeps the group
    /// unchanged when hiding would leave it with no rows at all.
    func shownGroup(_ group: ProviderGroup, descriptor: (PlacedWidget) -> WidgetDescriptor?) -> ProviderGroup {
        func isShown(_ widget: PlacedWidget) -> Bool {
            guard let descriptor = descriptor(widget), descriptor.hidesWithoutData else { return true }
            return data(for: descriptor, in: group).hasData
        }
        let alwaysShown = group.alwaysShownWidgets.filter(isShown)
        let expanded = group.expandedWidgets.filter(isShown)
        if alwaysShown.isEmpty && expanded.isEmpty { return group }
        if alwaysShown.isEmpty {
            return ProviderGroup(provider: group.provider, alwaysShownWidgets: expanded, expandedWidgets: [],
                                 accounts: group.accounts)
        }
        return ProviderGroup(provider: group.provider, alwaysShownWidgets: alwaysShown, expandedWidgets: expanded,
                             accounts: group.accounts)
    }
}
