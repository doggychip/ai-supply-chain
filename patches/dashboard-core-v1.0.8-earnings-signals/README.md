# dashboard-core v1.0.8 — earnings fundamentals + rules-based buy-signal

Brings real earnings results onto the dashboards and adds a transparent,
auditable "is this good to buy" **signal** — explicitly **NOT financial
advice**, a mechanical score from objective Yahoo data.

## What "live & accurate" can and cannot mean (read this first)

| Data | Source | Live now? |
|------|--------|-----------|
| price / change / %chg | chart endpoint, 60s poll | ✅ v1.0.5 |
| mcap / PE / EPS / div / 52w / volume | quoteSummary, 60s poll | ✅ v1.0.7 |
| **next earnings date** | quoteSummary `calendarEvents` | ✅ **v1.0.8** |
| **last 4Q EPS beat/miss + surprise%** | `earningsHistory` | ✅ **v1.0.8** |
| **quarterly revenue trend** | `earnings.financialsChart` | ✅ **v1.0.8** |
| **forward EPS/rev growth consensus** | `earningsTrend` | ✅ **v1.0.8** |
| **analyst rating + price targets** | `financialData` | ✅ **v1.0.8** |
| **buy-signal score (0-100)** | computed client-side from ↑ | ✅ **v1.0.8** |
| hand-written thesis paragraphs | editorial HTML | ❌ can't verify, untouched |
| conviction scores (98/100), signal tags | editorial/subjective | ❌ untouched |
| sector KPIs ($600B capex, etc.) | hand-set forecasts | ❌ untouched |

The signal **does not** replace the editorial conviction scores — it sits
alongside them as an objective, rules-based second opinion.

## The signal — fully auditable, 5 components × 20 pts, normalized

Computed in `client/signals.js` → `computeSignal(ticker)`. Each component is
skipped if its data is missing; the final score is normalized over the
components that had data (so a ticker lacking analyst coverage isn't zeroed).

1. **Last-Q EPS beat** (20) — beat ≥10% surprise=20, ≥2%=16, beat=12, miss=4
2. **Beat streak** (20) — 5 pts per beat quarter over last 4
3. **Forward EPS growth** (20) — ≥25% YoY=20, ≥15%=15, ≥5%=10, >0%=5, ≤0=0
4. **Analyst consensus** (20) — recommendationMean ≤1.5=20 … >3.5=0
5. **Upside to mean PT** (20) — uses the **live price**: ≥25%=20, ≥10%=15, ≥0%=8, ≥-10%=4, else 0

`≥70 = Strong · 45-69 = Moderate · <45 = Weak`. Hover any score in the table
to see the per-component breakdown. The signal re-computes as prices move
(upside-to-PT shifts), via the `live-prices-updated` event.

## What ships

- **server/yahoo.js** — `quoteSummaryToFundamentals()` extractor (+ the existing
  crumb-dance helpers reused).
- **server/index.js** — `GET /api/fundamentals?symbols=…` route, own 1h cache
  (earnings data changes ~quarterly, not intraday). Fetches the earnings
  module set per ticker; failures degrade to omitting that ticker.
- **client/signals.js** — fetches `/api/fundamentals` once on load, merges into
  `SW_DATA/TICKER_DATA[X].fundamentals`, exposes `window.computeSignal` and
  `window.tickerSignals`.
- **client/signals-ui.js** — **purely additive**: injects an "Earnings &
  Signals" nav item + section (no edits to existing markup), renders the table,
  and **rebuilds any stale hardcoded earnings calendar** (`#ecalContainer`)
  with the live next-earnings dates — fixing the "dates already passed" issue.

Each dashboard adds exactly **two `<script>` tags**; everything else
self-injects.

## Tests (offline, no network)

```
$ node lib/signals/signals.test.js
all 28 signal/fundamentals tests passed     # extractor + signal math
$ node patches/.../ui-render.smoke.js
SMOKE PASS                                  # full render path, MSFT → 85 "Strong"
```

The signal math is checked against a worked example: a full-data ticker at
$460 with the sample payload scores exactly **85 (Strong)**; the same ticker
at $530 scores lower as upside-to-PT compresses.

## Caveat — couldn't validate against live Yahoo from the build sandbox

Yahoo geo-blocks the build environment (403). The field extraction is based on
the documented `quoteSummary` v10 response shape. The deploy script smoke-tests
the **real** `/api/fundamentals` response on your Mac before merging, and warns
(without failing) if Yahoo is momentarily rate-limiting the crumb dance.

## Deploy

```bash
git -C ~/ai-supply-chain fetch origin claude/update-share-price-dashboard-HCLqD
git -C ~/ai-supply-chain show origin/claude/update-share-price-dashboard-HCLqD:patches/live-prices-deploy/deploy-v1.0.8.sh > /tmp/deploy-v108.sh
bash /tmp/deploy-v108.sh
```

Tags dashboard-core v1.0.8, then bumps + adds the two script tags to both
dashboards, smoke-tests `/api/fundamentals`, and opens a PR per repo.

## Known follow-ups (not in v1.0.8)

- Conviction-card analyst-row text ("Avg PT $521 · 87.5% Bullish") is still
  hand-curated HTML. The live data is now in `TICKER_DATA[X].fundamentals`;
  wiring it into those specific cards is a separate per-dashboard render task.
- The signal weights are fixed/equal. If you want to tune them (e.g. weight
  earnings momentum higher), they're all in one function in `signals.js`.
