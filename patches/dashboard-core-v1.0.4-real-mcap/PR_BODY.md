# fix: fetch real marketCap from Yahoo; ratio-scaling becomes fallback

## Problem

Per-ticker `marketCap` was derived by scaling the baseline by the price
ratio. When the baseline carried a stale share count, every refresh
perpetuated the error. Flagged on `ai-supply-chain` PR #20 by Codex:

| Ticker | written | implied shares | real shares | error |
|--------|---------|---------------|-------------|-------|
| AMD  | $509.4B | 1.00B | ~1.62B | **−38%** |
| MU   | $799.2B | 0.77B | ~1.12B | **−31%** |
| ARM  | $291.6B | 0.71B | ~1.05B | **−32%** |
| MRVL | $150.0B | 0.68B | ~0.86B | **−20%** |

## Fix

Three-tier preference per ticker:

1. **Yahoo's reported `marketCap`** (`quoteSummary` → `summaryDetail.marketCap`
   or `price.marketCap`). Strongest signal, used when available.
2. **`price * sharesOutstanding`** (`defaultKeyStatistics.sharesOutstanding`).
   Drift-free as long as shares are fresh.
3. **Ratio scaling** — the legacy v1.0.3 behavior, kept as a safety net for
   when Yahoo's crumb dance fails or the lookup is blocked.

A new helper `fetchMcapAndShares(ticker)` runs the crumb dance lazily
(cached process-wide) and returns `null` on any failure, so a bad day at
Yahoo can never break the refresh — it degrades to v1.0.3 behavior for the
affected tickers.

Backward-compatible: `rewriteAiLine(line, q)` (no third arg) behaves
exactly as v1.0.3. The new behavior is opt-in by passing `extra`.

## Changes

- `lib/update-prices/fetch.js` — adds `ensureCrumb()`,
  `fetchMcapAndShares()`, and the test-only `_resetCrumbCacheForTests()`.
  `derivePrev()` and `fetchQuote()` are unchanged.
- `lib/update-prices/ai-schema.js` — adds exported `resolveNewMcap()`;
  `rewriteAiLine` accepts an optional third arg; `runAiSchema` fetches
  mcap/shares per ticker.
- `lib/update-prices/sw-schema.js` — three-tier choice applied to the
  numeric `t.marketCap` field.
- `lib/update-prices/real-mcap.test.js` — 12 offline cases, all passing.

## Tests

```
$ node lib/update-prices/real-mcap.test.js
all 12 real-mcap tests passed
```

Includes the AMD bug verbatim ($509.4B → $826.4B with real shares), the
`$1xx` hi52/lo52 backref guard, and explicit checks that omitting `extra`
matches v1.0.3 behavior.

## Risk

Low. Failures at every step in the new path fall back to v1.0.3 behavior.
One extra network request per ticker (rate-limited by the existing
150 ms inter-ticker sleep). No new dependencies.

## After merge

Tag `v1.0.4`; consuming dashboards bump `#v1.0.3 → #v1.0.4`, `rm -rf
node_modules package-lock.json && npm install`, and re-run `update-prices`.
CLI output gains an `N real / M scaled` summary so it's obvious how
often the real path is hitting.
