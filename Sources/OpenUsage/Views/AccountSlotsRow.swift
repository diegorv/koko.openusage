import SwiftUI

/// A merged percent row: the combined value in the header, one equal bar slot per account filled by
/// that account alone, and a line per account with its own value and reset.
struct AccountSlotsRow: View {
    let data: WidgetData
    var onToggleMeterStyle: (() -> Void)?

    @AppStorage(DensitySetting.key) private var density = DensitySetting.regular

    private static let slotSpacing: CGFloat = 3

    private var rows: [(account: MergedAccount, data: WidgetData)] { data.accountRows }

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
                ForEach(rows, id: \.account.providerID) { row in
                    slot(row.account, fraction: row.data.fraction)
                }
            }
            .frame(height: density.meterHeight)
            .accessibilityHidden(true)

            ForEach(rows, id: \.account.providerID) { row in
                accountLine(row.account, row.data)
            }
        }
    }

    /// Bars carry account colors, so the low-quota signal lives on this number.
    @ViewBuilder
    private var combinedValue: some View {
        let label = Text(data.boundedHeadline).foregroundStyle(valueStyle)
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

    private func accountLine(_ account: MergedAccount, _ row: WidgetData) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(AccountColors.color(account.colorIndex))
                .frame(width: 7, height: 7)
            Text(account.shortName)
                .foregroundStyle(.primary)
                .truncationMode(.tail)
            Spacer(minLength: 8)
            Text(([row.boundedHeadline] + [row.resetLabel].compactMap { $0 }).joined(separator: " · "))
                .foregroundStyle(.secondary)
                .layoutPriority(1)
        }
        .font(.system(size: density.supportingPointSize))
        .lineLimit(1)
    }
}
