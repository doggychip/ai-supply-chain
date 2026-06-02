# dashboard-core fix: real marketCap from Yahoo (v1.0.3 → v1.0.4)

## Problem

`update-prices` derives `marketCap` by **scaling the baseline mcap by the
price ratio**. When the baseline was hand-entered with a stale share count
— common for tickers that have done buybacks, issuance, or simply weren't
captured fresh — every refresh perpetuates the error.

Flagged on PR #20 by Codex (`r3338393843`) and confirmed by computing
implied shares = `written_mcap / price`:

| Ticker | written | implied shares | real shares (Yahoo) | error |
|---|---|---|---|---|
| AMD  | $509.4B | 1.00B | ~1.62B | **−38%** |
| MU   | $799.2B | 0.77B | ~1.12B | **−31%** |
| ARM  | $291.6B | 0.71B | ~1.05B | **−32%** |
| MRVL | $150.0B | 0.68B | ~0.86B | **−20%** |

The side panel renders `mcap` directly, so users see materially wrong
valuations.

## Fix

Replace the ratio-scaling-only path with a three-tier preference:

1. **Yahoo's reported `marketCap`** — strongest, used when available.
2. **`price * sharesOutstanding`** — drift-free as long as shares are fresh.
3. **Ratio scaling** — legacy v1.0.3 fallback, used only when Yahoo's
   quoteSummary fetch fails (e.g. crumb dance blocked, network error).

The new data comes from Yahoo's `quoteSummary` v10 endpoint, which
requires a one-time crumb+cookie dance. The fetch is best-effort — any
failure returns `null` and the old behavior takes over for that ticker,
so a bad day at Yahoo can't break the refresh.

The CLI now logs `mcap*` (real), `mcap=p×s` (price×shares), or `mcap≈`
(ratio-scaled) per ticker, plus a summary line: `mcap: N real / M scaled`.

### What changed

- `lib/update-prices/fetch.js`
  - `derivePrev()` unchanged (v1.0.3 still in effect).
  - **New**: `ensureCrumb()` — lazy, process-cached crumb+cookie dance.
  - **New**: `fetchMcapAndShares(ticker)` — pulls `marketCap` /
    `sharesOutstanding` from `quoteSummary` (modules `summaryDetail`,
    `defaultKeyStatistics`, `price`). Returns `null` on any failure.
  - **Test-only**: `_resetCrumbCacheForTests()` exported.
- `lib/update-prices/ai-schema.js`
  - **New**: `resolveNewMcap({ real, price, oldMcap, oldPrice })` — pure,
    exported helper encoding the three-tier preference.
  - `rewriteAiLine(line, q, extra?)` — accepts optional `extra =
    { marketCap, sharesOutstanding }`. Backward-compatible: omit `extra`
    and behavior matches v1.0.3 (ratio scaling).
  - `runAiSchema` now calls `fetchMcapAndShares` per ticker.
- `lib/update-prices/sw-schema.js`
  - Same three-tier choice applied to the numeric `t.marketCap` field.
  - Per-ticker log adds the same `mcap*` / `mcap=p×s` / `mcap≈` tag.

### Tests

`lib/update-prices/real-mcap.test.js` — 12 offline cases (no network):

- `resolveNewMcap` priority across all four sources, including null and
  zero/negative guard.
- `rewriteAiLine` integration with each tier.
- The **AMD bug case verbatim**: `$509.4B → $826.4B` with real shares.
- The `$1xx` hi52/lo52 backref guard from v1.0.3 still holds alongside
  the new mcap path.

```
$ node lib/update-prices/real-mcap.test.js
all 12 real-mcap tests passed
```

## Risk

- **Crumb dance:** Yahoo occasionally changes the consent/crumb flow.
  The implementation is defensive (anything wrong → `null` → legacy
  fallback), so a regression at Yahoo degrades to v1.0.3 behavior rather
  than breaking the refresh.
- **Rate limits:** Adds one extra request per ticker. The existing
  150 ms inter-ticker delay should keep this well inside Yahoo's
  tolerances; if not, lower frequency by caching shares between runs.
- **Privacy:** The crumb cookies are kept in-process only; nothing is
  persisted to disk.

## Apply (in the `doggychip/dashboard-core` repo)

```bash
git checkout -b fix/real-marketcap
git apply /path/to/fetch.js.patch
git apply /path/to/ai-schema.js.patch
git apply /path/to/sw-schema.js.patch
cp /path/to/real-mcap.test.js lib/update-prices/real-mcap.test.js
node --check lib/update-prices/fetch.js
node --check lib/update-prices/ai-schema.js
node --check lib/update-prices/sw-schema.js
node lib/update-prices/real-mcap.test.js   # expect: all 12 real-mcap tests passed

git add -A
git commit -m "fix: fetch real marketCap from Yahoo; ratio-scaling becomes fallback"
git push -u origin fix/real-marketcap
# review, merge, tag:
git checkout main && git pull
git tag v1.0.4 && git push origin v1.0.4
# verify the tag actually has the change (expect >= 2):
git show v1.0.4:lib/update-prices/fetch.js | grep -c fetchMcapAndShares
```

## Then in each consuming dashboard

```bash
cd ~/ai-supply-chain     # or software-supply-chain, semi-equipment
npm pkg set dependencies.dashboard-core="git+https://github.com/doggychip/dashboard-core.git#v1.0.4"
rm -rf node_modules package-lock.json
npm install
npm run update-prices     # output now includes 'N real / M scaled' summary
```

For ai-supply-chain specifically, the held PR #20 (`chore/price-refresh-v2`)
should be amended with this re-run before merging — that's the branch the
Codex review was made against.
