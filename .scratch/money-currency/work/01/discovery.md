# Issue 01 discovery: money values carry their currency

No `spec.md` exists for this feature; the Issue is the only source.

## Files that change
- `Sources/OpenUsage/Models/MetricLine.swift:6-62` — `ProgressFormat.dollars` becomes `dollars(currency: String? = nil)`; Codable writes `currency` only when set and reads it with `decodeIfPresent` (old snapshots decode as USD).
- `Sources/OpenUsage/Models/MetricValue.swift:10-29` — add `var currency: String?` (nil = USD); synthesized Codable already uses decodeIfPresent/encodeIfPresent.
- `Sources/OpenUsage/Models/MetricKind.swift:9` — comment: money in its currency, USD when none.
- `Sources/OpenUsage/Support/Formatters.swift:6` — `currency(_:fractionDigits:currencyCode:)`, default USD.
- `Sources/OpenUsage/Support/MetricFormatter.swift:23-46,60-64` — `number(_:kind:style:currency:)`; compact/tray forms prefix the currency's en_US symbol (`R$`, `$`); `string(for:)` passes `value.currency`.
- `Sources/OpenUsage/Models/WidgetData.swift` — add `currency: String?`; `format`, `menuBarValue`, `boundedSubtitle` (limit line), `unboundedDetail`, `valueText` pass it (values pass their own).
- `Sources/OpenUsage/Stores/WidgetDataStore.swift:656-668` — progress resolve copies `format.currency`.
- `Sources/OpenUsage/Providers/Claude/ClaudeUsageMapper.swift:212-231` — read `extra_usage.currency` (trimmed, uppercased, empty -> nil) and `decimal_places` (default 2) for minor-unit conversion.
- `Sources/OpenUsage/Services/LocalLimitsAPI.swift:96-147` — progress unit = lowercased currency or `usd`; value rows of kind `.dollars` with a currency report it lowercased, else the descriptor's unit.
- Construction sites `format: .dollars` -> `.dollars()` (OpenRouter, Cursor, Ollama, Claude mappers; tests).
- Docs: `docs/local-http-api.md` (unit + format currency), `docs/adding-a-provider.md:33`, `docs/providers/claude.md`.

## Plan (test-first)
1. Tests: ProgressFormat/MetricValue round-trip with currency, old JSON without currency decodes as USD (nil).
2. Tests: MetricFormatter BRL in tray/row/full and compact (>= 1000); USD unchanged.
3. Tests: Claude mapper BRL payload (progress and uncapped values), USD payload, no-currency payload, decimal_places.
4. Tests: WidgetData from a BRL line renders R$ in headline, menu bar, limit subtitle.
5. Tests: LocalLimitsAPI Claude extraUsage unit `brl`; USD stays `usd`.
6. Implement, then docs.

## Prior-art tests
`Tests/OpenUsageTests/ClaudeProviderTests.swift:185-255`, `LocalLimitsAPITests.swift:130-145`, `WidgetDataStoreTests.swift:360-450`, MetricFormatter tests (grep `MetricFormatterTests`).

## Defaults taken
- Currency code stored as uppercased ISO code; `"USD"` from the payload is stored as `"USD"` (formats identically to nil).
- `decimal_places` missing or invalid -> 2 (cents), matching today's behavior.
- Spend estimate tiles, Total Spend ring, model breakdown stay USD (imputed at API rates; out of scope).
- Symbol comes from an en_US `NumberFormatter` (BRL -> `R$`); an unknown code prints the code itself.

## Risks
- `.dollars` -> `.dollars()` is source-breaking for every construction site; compiler finds them all.
- Equality: `.dollars()` != `.dollars(currency: "USD")`; tests on USD payloads compare with the stored code.
