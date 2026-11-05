import Foundation

/// One account folded into a merged provider card: which provider id it is, the short name the legend
/// prints, and the slot of its tick color.
struct MergedAccount: Hashable {
    let providerID: String
    let shortName: String
    let colorIndex: Int

    /// The legend name for an account card: its display name without the family prefix ("Claude: ",
    /// "Claude — ") and its trailing " (…)" detail (a Swap account's email, a hub's label), cut to the
    /// local part of an email, the way the prototype labels accounts. `keepingDetail` keeps that detail
    /// (also cut to an email's local part) in parentheses, for accounts whose plain names collide.
    static func shortName(displayName: String, familyName: String, keepingDetail: Bool = false) -> String {
        var name = Substring(displayName)
        if name.hasPrefix(familyName) {
            name = name.dropFirst(familyName.count)
            name = name.drop { $0 == ":" || $0 == "—" || $0 == " " }
        }
        var detail = ""
        if name.hasSuffix(")"), let open = name.range(of: " (", options: .backwards) {
            detail = localPart(name[open.upperBound...].dropLast())
            name = name[..<open.lowerBound]
        }
        let trimmed = localPart(name)
        let short = trimmed.isEmpty ? familyName : trimmed
        return keepingDetail && !detail.isEmpty ? "\(short) (\(detail))" : short
    }

    private static func localPart(_ text: Substring) -> String {
        let cut = text.firstIndex(of: "@").map { text[..<$0] } ?? text
        return cut.trimmingCharacters(in: .whitespaces)
    }

    /// Short names for one family's accounts, in order. Names that two accounts share keep their detail,
    /// so the legend can tell two Swap accounts in one organization, or one email on two hubs, apart.
    static func shortNames(displayNames: [String], familyName: String) -> [String] {
        let plain = displayNames.map { shortName(displayName: $0, familyName: familyName) }
        let counts = Dictionary(plain.map { ($0, 1) }, uniquingKeysWith: +)
        return zip(displayNames, plain).map { displayName, name in
            counts[name, default: 0] > 1
                ? shortName(displayName: displayName, familyName: familyName, keepingDetail: true)
                : name
        }
    }
}

/// Merged rows are re-merged on every render, so each distinct warning is written to the log once a run.
private enum MergeWarnings {
    private static let lock = NSLock()
    private nonisolated(unsafe) static var logged: Set<String> = []

    static func warnOnce(_ message: String) {
        lock.lock()
        let isNew = logged.insert(message).inserted
        lock.unlock()
        if isNew { AppLog.warn(.refresh, message) }
    }
}

/// An account's own reading on a merged bar, drawn as a colored tick at `fraction`.
struct AccountTick: Hashable {
    var account: MergedAccount
    let used: Double
    let limit: Double
    var resetsAt: Date? = nil

    /// Share of the limit used, 0...1.
    var fraction: Double {
        guard limit > 0 else { return 0 }
        return min(max(used / limit, 0), 1)
    }
}

/// One account's resolved data for the metric being merged.
struct AccountReading {
    let account: MergedAccount
    let data: WidgetData
    /// The account has no limit readings at all right now (rate limited, refresh failed), as opposed
    /// to simply lacking this one metric.
    var isUnavailable = false
}

extension WidgetData {
    /// A merged percent row shows one slot per account instead of a single averaged bar.
    var showsAccountSlots: Bool {
        kind == .percent && isBounded && !accountTicks.isEmpty
    }

    /// Bounded money and count rows have no slots: they keep the summed bar with a tick per account.
    var showsAccountTicks: Bool {
        !accountTicks.isEmpty && !showsAccountSlots
    }

    /// Each account's own reading on a slotted row, as row data so it formats and follows the global
    /// Used/Left and reset settings like any other row.
    var accountRows: [(account: MergedAccount, data: WidgetData)] {
        guard showsAccountSlots else { return [] }
        return accountTicks.map { tick in
            var row = self
            row.used = tick.used
            row.limit = tick.limit
            row.resetsAt = tick.resetsAt
            row.accountTicks = []
            row.unavailableAccounts = []
            return (tick.account, row)
        }
    }

    /// A family card's row when the family has one account: its reading, kept as that account's own.
    static func soloAccount(_ reading: AccountReading) -> WidgetData {
        var row = reading.data
        if row.hasData { row.accountTicks = ticks([reading]) }
        return row
    }

    /// The row with generic account names, for images that leave the app: short names are usually an
    /// email's local part.
    func anonymizingAccounts() -> WidgetData {
        func anonymous(_ account: MergedAccount) -> MergedAccount {
            MergedAccount(providerID: account.providerID, shortName: "Account \(account.colorIndex + 1)",
                          colorIndex: account.colorIndex)
        }
        var row = self
        row.accountTicks = accountTicks.map { tick in
            var tick = tick
            tick.account = anonymous(tick.account)
            return tick
        }
        row.unavailableAccounts = unavailableAccounts.map(anonymous)
        return row
    }

    /// Folds the same metric of several accounts into one row. Accounts without the metric
    /// (`hasData == false`) are left out. Percent meters average; dollar and count amounts (meters,
    /// `.values` rows, chart days) sum. The reset is the soonest one, with that account's window
    /// length so the pace stays consistent. Bounded rows keep each account's own reading as a tick.
    /// A single reading comes back unchanged.
    static func merging(_ readings: [AccountReading]) -> WidgetData {
        guard readings.count > 1 else { return readings[0].data }
        let present = readings.filter(\.data.hasData)
        guard var merged = present.first?.data else { return readings[0].data }
        merged.unavailableAccounts = readings.filter { $0.isUnavailable && !$0.data.hasData }.map(\.account)
        guard present.count > 1 else {
            merged.accountTicks = ticks(present)
            return merged
        }
        let all = present.map(\.data)

        if merged.isChart {
            merged.chartPoints = summedChartPoints(all.map(\.chartPoints))
        } else if merged.valueTextOverride == nil {
            if !merged.values.isEmpty {
                merged.values = summedValues(all.map(\.values))
            } else if merged.kind == .percent, let limit = merged.limit {
                let fractions = all.map { data in data.limit.map { $0 > 0 ? data.used / $0 : 0 } ?? 0 }
                merged.used = fractions.reduce(0, +) / Double(fractions.count) * limit
            } else {
                // Amounts in another currency can't be added; they keep only their own tick.
                let sameCurrency = all.filter { $0.currency == merged.currency }
                if sameCurrency.count < all.count {
                    MergeWarnings.warnOnce("Merged \(merged.title) skips \(all.count - sameCurrency.count) account(s) in another currency")
                }
                merged.used = sameCurrency.map(\.used).reduce(0, +)
                if merged.limit != nil { merged.limit = sameCurrency.compactMap(\.limit).reduce(0, +) }
            }
        }

        let resets = all.compactMap { data in data.resetsAt.map { (at: $0, periodMs: data.periodDurationMs) } }
        if let soonest = resets.min(by: { $0.at < $1.at }) {
            merged.resetsAt = soonest.at
            merged.periodDurationMs = soonest.periodMs
        }
        merged.expiriesAt = all.flatMap(\.expiriesAt).sorted()
        var seenModels = Set<String>()
        merged.unknownModels = all.flatMap(\.unknownModels).filter { seenModels.insert($0).inserted }
        // Per-model spend isn't summed across accounts, so a merged row has no model breakdown.
        merged.modelBreakdown = nil
        merged.accountTicks = ticks(present)
        return merged
    }

    private static func ticks(_ present: [AccountReading]) -> [AccountTick] {
        present.compactMap { reading in
            guard !reading.data.isChart, reading.data.valueTextOverride == nil,
                  let limit = reading.data.limit else { return nil }
            return AccountTick(account: reading.account, used: reading.data.used, limit: limit,
                               resetsAt: reading.data.resetsAt)
        }
    }

    /// Adds each list's values into the first list's slots, index by index, where the kind and
    /// currency match (a spend row's dollars with dollars, its tokens with tokens).
    private static func summedValues(_ lists: [[MetricValue]]) -> [MetricValue] {
        var result = lists[0]
        for list in lists.dropFirst() {
            for index in result.indices where index < list.count {
                let value = list[index]
                guard value.kind == result[index].kind, value.currency == result[index].currency else { continue }
                result[index].number += value.number
                result[index].estimated = result[index].estimated || value.estimated
            }
        }
        return result
    }

    /// Sums chart points by their day label, in the order the days first appear. A summed day drops
    /// its pre-formatted readout, which described one account only.
    private static func summedChartPoints(_ lists: [[MetricChartPoint]]) -> [MetricChartPoint] {
        var result: [MetricChartPoint] = []
        var indexByLabel: [String: Int] = [:]
        for point in lists.joined() {
            if let index = indexByLabel[point.label] {
                result[index].value += point.value
                result[index].valueLabel = nil
            } else {
                indexByLabel[point.label] = result.count
                result.append(point)
            }
        }
        return result
    }
}
