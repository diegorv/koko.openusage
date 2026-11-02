import Foundation

extension WidgetDataStore {
    /// The row data for `descriptor` as `group`'s card shows it. On a merged card the descriptor is the
    /// base account's (`claude.weekly`); each merged account's own metric (`claude@ab12cd34.weekly`)
    /// is read and folded in with `WidgetData.merging`. A normal card reads the descriptor directly.
    func data(for descriptor: WidgetDescriptor, in group: ProviderGroup) -> WidgetData {
        guard !group.accounts.isEmpty, descriptor.id.hasPrefix(group.provider.id + ".") else {
            return data(for: descriptor)
        }
        let suffix = descriptor.id.dropFirst(group.provider.id.count)
        let readings = group.accounts.map { account in
            let accountDescriptor = self.descriptor(id: account.providerID + suffix)
            var reading = accountDescriptor.map { data(for: $0) } ?? data(for: descriptor)
            // An account card without this metric has nothing to add.
            if accountDescriptor == nil { reading.hasData = false }
            return AccountReading(account: account, data: reading)
        }
        return WidgetData.merging(readings)
    }
}
