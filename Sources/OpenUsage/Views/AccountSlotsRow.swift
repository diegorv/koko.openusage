import SwiftUI

/// A merged percent row: the combined value in the header, one equal bar slot per account filled by
/// that account alone, and a line per account with its own value and reset.
struct AccountSlotsRow: View {
    let data: WidgetData
    var onToggleMeterStyle: (() -> Void)?

    @AppStorage(DensitySetting.key) private var density = DensitySetting.regular

    private static let slotSpacing: CGFloat = 3

    /// Every account in its card order; one with no readings has no row and keeps an empty slot.
    private var slots: [(account: MergedAccount, row: WidgetData?)] {
        let reading = data.accountRows.map { (account: $0.account, row: Optional($0.data)) }
        let missing = data.unavailableAccounts.map { (account: $0, row: WidgetData?.none) }
        return (reading + missing).sorted { $0.account.colorIndex < $1.account.colorIndex }
    }

    /// The combined value leaves unavailable accounts out, so it says so.
    private var combinedText: String {
        let missing = data.unavailableAccounts.count
        return missing == 0 ? data.boundedHeadline : "\(data.boundedHeadline) · \(missing) missing"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: density.rowInnerSpacing) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(data.title)
                    .foregroundStyle(.primary)
                Spacer(minLength: 8)
                combinedValue
            }
            .font(.system(size: density.labelPointSize, weight: .semibold))
            .lineLimit(1)

            HStack(spacing: Self.slotSpacing) {
                ForEach(slots, id: \.account.providerID) { slot in
                    self.slot(slot.account, fraction: slot.row?.fraction ?? 0)
                }
            }
            .frame(height: density.meterHeight)
            .accessibilityHidden(true)

            if data.accountsReadAlike {
                Text(data.allAccountsSummary())
                    .font(.system(size: density.supportingPointSize))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else {
                ForEach(slots, id: \.account.providerID) { slot in
                    accountLine(slot.account, slot.row)
                }
            }
        }
    }

    /// Bars carry account colors, so the low-quota signal lives on this number.
    @ViewBuilder
    private var combinedValue: some View {
        let label = Text(combinedText).foregroundStyle(valueStyle)
        if let onToggleMeterStyle {
            Button(action: onToggleMeterStyle) { label }
                .buttonStyle(.plain)
                .hoverTooltip(data.meterStyleTooltip)
        } else {
            label
        }
    }

    private var valueStyle: AnyShapeStyle {
        switch data.meterState().severity {
        case .warning: Theme.meterFill(.warning)
        case .critical: Theme.meterFill(.critical)
        case .normal, nil: AnyShapeStyle(.primary)
        }
    }

    private func slot(_ account: MergedAccount, fraction: Double) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(.quaternary)
                if fraction > 0 {
                    Capsule()
                        .fill(AccountColors.color(account.colorIndex))
                        .frame(width: max(density.meterHeight, proxy.size.width * fraction))
                }
            }
        }
    }

    private func accountLine(_ account: MergedAccount, _ row: WidgetData?) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(AccountColors.color(account.colorIndex))
                .frame(width: 7, height: 7)
            Text(account.shortName)
                .foregroundStyle(.primary)
                .truncationMode(.tail)
            Spacer(minLength: 8)
            Text(row?.accountSummary(showsValue: slots.count > 1) ?? "No data")
                .foregroundStyle(isSpent(row) ? Theme.meterFill(.critical) : AnyShapeStyle(.secondary))
                .layoutPriority(1)
        }
        .font(.system(size: density.supportingPointSize))
        .lineLimit(1)
    }

    private func isSpent(_ row: WidgetData?) -> Bool {
        row?.meterState() == .spent && slots.count > 1
    }
}
