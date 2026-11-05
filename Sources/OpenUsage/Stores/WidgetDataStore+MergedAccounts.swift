import Foundation

extension WidgetDataStore {
    /// The row data for `descriptor` as `group`'s card shows it. On a merged card the descriptor is the
    /// base account's (`claude.weekly`); each merged account's own metric (`claude@ab12cd34.weekly`)
    /// is read and folded in with `WidgetData.merging`. A normal card reads the descriptor directly.
    func data(for descriptor: WidgetDescriptor, in group: ProviderGroup) -> WidgetData {
        data(for: descriptor, providerID: group.provider.id, accounts: group.accounts)
    }

    /// The value `group`'s menu-bar item shows: merged across its accounts the same way as the card.
    func data(for descriptor: WidgetDescriptor, in group: ProviderMetrics) -> WidgetData {
        data(for: descriptor, providerID: group.provider.id, accounts: group.accounts)
    }

    private func data(for descriptor: WidgetDescriptor, providerID: String, accounts: [MergedAccount]) -> WidgetData {
        guard !accounts.isEmpty, descriptor.id.hasPrefix(providerID + ".") else {
            return data(for: descriptor)
        }
        let suffix = descriptor.id.dropFirst(providerID.count)
        let readings = accounts.map { account in
            let accountDescriptor = self.descriptor(id: account.providerID + suffix)
            var reading = accountDescriptor.map { data(for: $0) } ?? data(for: descriptor)
            // An account card without this metric has nothing to add.
            if accountDescriptor == nil { reading.hasData = false }
            return AccountReading(account: account, data: reading, isUnavailable: !hasLimitReadings(account.providerID))
        }
        return readings.count == 1 ? WidgetData.soloAccount(readings[0]) : WidgetData.merging(readings)
    }

    private func hasLimitReadings(_ providerID: String) -> Bool {
        descriptors(forProvider: providerID).contains { $0.sample.kind == .percent && data(for: $0).hasData }
    }
}
