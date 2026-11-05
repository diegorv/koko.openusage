import Foundation

enum UsageHistorySnapshotRenderer {
    private static let historyLabels: Set<String> = ["Today", "Yesterday", "Last 30 Days", "Usage Trend"]

    static func render(
        local snapshot: ProviderSnapshot,
        history: ProviderUsageHistory,
        descriptor: UsageHistoryDescriptor,
        now: Date = Date()
    ) -> ProviderSnapshot {
        var result = snapshot
        result.lines.removeAll { historyLabels.contains($0.label) }
        let baseNote = descriptor.sourceNote
        SpendTileMapper.appendTokenUsage(
            history.series,
            to: &result.lines,
            now: now,
            estimated: descriptor.estimatedCost,
            unknownModelsByDay: history.unknownModelsByDay,
            modelUsage: history.modelUsage,
            modelSourceNote: baseNote,
            fallbackPricingModelsByDay: history.fallbackPricingModelsByDay
        )
        SpendTileMapper.appendUsageTrend(
            history.series,
            to: &result.lines,
            now: now,
            note: baseNote,
            fallbackPricingModelsByDay: history.fallbackPricingModelsByDay
        )
        return result
    }
}
