# fix: derive daily `prev` close from the series, not the 6-month window start

## Problem

`lib/update-prices/fetch.js` requests `range=6mo&interval=1d` and reads
`meta.previousClose`, falling back to `meta.chartPreviousClose`. On that
long-range endpoint `previousClose` is frequently absent, so the fallback —
the close **before the first bar of the 6-month window** — is used. That turns
`chg` / `chgPct` into a ~6-month return instead of a daily move.

Hit in production on the 2026-06-02 AI-dashboard refresh (106 tickers reported
"up" 20–700% on the day):

| Ticker | price | bad `prev` | bad chgPct |
|--------|-------|-----------|-----------|
| AMD    | 510.13 | 219.76 | **+132%** |
| MU     | 1035.50 | 240.46 | **+331%** |
| SNDK   | 1761.43 | 210.17 | **+738%** |

`price`, 52-week hi/lo, `mcap`, and `pe` are unaffected (they don't use
`prev`). The bug affects every dashboard that consumes dashboard-core
(ai / software / semi).

## Fix

Add a pure, exported `derivePrev(meta, closes)` that takes the
**second-to-last valid daily close** (the prior trading session, already
present in the fetched series). The meta fields are used only as a fallback
when the series is too short (e.g. a freshly-listed ticker). `fetchQuote` now
builds the `closes` array first and derives `prev` from it.

After the fix, the AMD example is **+1.02%** instead of +132%.

## Tests

`lib/update-prices/fetch.prev.test.js` — 7 offline cases (no network):
normal series, nulls/holidays ignored, the window-start regression, both
short-series fallbacks, empty → null, and non-positive closes. All passing.

```
$ node lib/update-prices/fetch.prev.test.js
all 7 derivePrev tests passed
```

## Risk

Low. Behavior is unchanged when the meta fields were already correct (the
series-derived value matches the prior close). Only the previously-wrong
long-range case changes. No API surface change beyond the added export.

## After merge

Tag `v1.0.3`; consuming dashboards bump the pinned dep and re-run
`update-prices`.
