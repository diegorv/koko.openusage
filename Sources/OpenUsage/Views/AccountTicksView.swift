import SwiftUI

/// Per-account colors on a merged provider card. Blue, yellow and red are left out: the bar's fill
/// already uses them for its severity.
enum AccountColors {
    private static let palette: [Color] = [.orange, .purple, .teal, .pink, .mint, .brown]

    static func color(_ index: Int) -> Color {
        palette[index % palette.count]
    }
}

/// The colored ticks a merged card's bar carries, one per account at that account's own reading. In
/// Left mode a tick marks what the account has left, matching the fill.
struct AccountTicksView: View {
    let ticks: [AccountTick]
    let displayMode: WidgetDisplayMode
    let meterHeight: CGFloat

    private static let width: CGFloat = 2
    private static let overhang: CGFloat = 6

    var body: some View {
        GeometryReader { proxy in
            ForEach(ticks, id: \.account.providerID) { tick in
                RoundedRectangle(cornerRadius: 1)
                    .fill(AccountColors.color(tick.account.colorIndex))
                    .frame(width: Self.width, height: meterHeight + Self.overhang)
                    .offset(x: offset(track: proxy.size.width, tick: tick), y: -Self.overhang / 2)
            }
        }
        .frame(height: meterHeight)
    }

    private func offset(track: CGFloat, tick: AccountTick) -> CGFloat {
        let fraction = displayMode == .remaining ? 1 - tick.fraction : tick.fraction
        let centered = track * fraction - Self.width / 2
        return min(max(centered, 0), max(track - Self.width, 0))
    }
}

extension View {
    /// Lays a merged row's account ticks over its meter; a no-op for rows without ticks.
    func accountTicksOverlay(_ data: WidgetData, meterHeight: CGFloat) -> some View {
        overlay {
            if data.hasData, data.showsAccountTicks {
                AccountTicksView(ticks: data.accountTicks, displayMode: data.displayMode, meterHeight: meterHeight)
            }
        }
    }
}

/// A merged card's key: a dot in each account's tick color beside its short name.
struct AccountLegendView: View {
    let accounts: [MergedAccount]

    @AppStorage(DensitySetting.key) private var density = DensitySetting.regular

    var body: some View {
        HStack(spacing: 10) {
            ForEach(accounts, id: \.providerID) { account in
                HStack(spacing: 4) {
                    Circle()
                        .fill(AccountColors.color(account.colorIndex))
                        .frame(width: 7, height: 7)
                    Text(account.shortName)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
        }
        .font(.system(size: density.supportingPointSize))
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
    }
}
