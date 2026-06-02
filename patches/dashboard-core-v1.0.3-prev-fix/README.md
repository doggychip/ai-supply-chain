# dashboard-core fix: daily `prev` close (v1.0.2 → v1.0.3)

## Problem

`npm run update-prices` (which calls `dashboard-core`'s `lib/update-prices/fetch.js`)
requests `range=6mo&interval=1d` from Yahoo and reads `meta.previousClose`, falling
back to `meta.chartPreviousClose`. On that long-range endpoint `previousClose` is
frequently absent, so the fallback — the close **before the start of the 6-month
window** — is used. That makes `chg` / `chgPct` a ~6-month return instead of a daily
move.

Observed in the 2026-06-02 AI-dashboard refresh (106 tickers, all "up" 20–700%):

| Ticker | price | bad `prev` | bad chgPct |
|--------|-------|-----------|-----------|
| AMD    | 510.13 | 219.76 | **+132%** |
| MU     | 1035.50 | 240.46 | **+331%** |
| SNDK   | 1761.43 | 210.17 | **+738%** |

`price`, 52-week hi/lo, `mcap` and `pe` are unaffected (they don't use `prev`); only
`chg`/`chgPct` are wrong. This bug affects **all** dashboards that share dashboard-core
(ai / software / semi).

## Fix

Derive `prev` from the **second-to-last valid daily close** (the prior trading
session), which is already present in the fetched series. Fall back to the meta
fields only when the series is too short (e.g. a freshly-listed ticker). See
`fetch.js.patch` (adds an exported, pure `derivePrev(meta, closes)` helper).

After the fix, AMD's day change is **+1.02%** instead of +132%.

## Apply (in the `doggychip/dashboard-core` repo)

```bash
git checkout -b fix/daily-prev-close
git apply /path/to/fetch.js.patch          # touches lib/update-prices/fetch.js
cp /path/to/fetch.prev.test.js lib/update-prices/fetch.prev.test.js
node lib/update-prices/fetch.prev.test.js  # expect: all 7 derivePrev tests passed
node --check lib/update-prices/fetch.js
# optional: wire the test into `npm test`
git add -A && git commit -m "fix: derive daily prev close from series, not 6mo window start"
git push -u origin fix/daily-prev-close
# review, merge, then tag the release:
git tag v1.0.3 && git push origin v1.0.3
```

## Then, back in each dashboard repo

```bash
# bump the pinned dependency
npm pkg set dependencies.dashboard-core="git+https://github.com/doggychip/dashboard-core.git#v1.0.3"
npm install
npm run update-prices:dry   # spot-check: day-change % should now be single/low-double digits
npm run update-prices
```

## Note on the held branch

`chore/price-refresh-20260602` was pushed with the buggy `chg`/`chgPct`. After
v1.0.3 lands and you re-run `update-prices`, either force-update that branch or open a
fresh one; don't merge it as-is.
