# AI Infrastructure — Full Value Chain Research Dashboard

A self-hosted equity research dashboard covering the **AI infrastructure value chain**: chips and accelerators, networking, foundries, hyperscalers, model labs, and the application layer riding on top. Live prices, technicals, sentiment, options, news, insider activity, correlations, stress-tests, and an MSX 2026 rotation map across the full AI universe.

> **Stack:** Node.js + Express, [dashboard-core](https://github.com/doggychip/dashboard-core) (shared proxy + cache + CLI), vanilla HTML/JS, Chart.js, Yahoo Finance v8 chart API.

---

## Quick start

```bash
git clone https://github.com/doggychip/ai-supply-chain.git
cd ai-supply-chain
npm install
npm start
```

Open `http://localhost:3000`. The server proxies live quotes from Yahoo on demand (via dashboard-core) and serves the static dashboard pages from `public/`.

To run on a different port:

```bash
PORT=4000 npm start
```

---

## What's in here

The dashboard is a **multi-page static site** with a shared layout. Each page is a single self-contained HTML file in `public/`.

| Page | File | What it shows |
|---|---|---|
| **Main** | `index.html` | 14-layer AI value-chain map, **MSX 2026 rotation view** (7 capital-rotation layers across 86 MSX-tagged tickers), bottleneck radar, layer detail cards with live prices, ticker side panel with sparkline + Yahoo link |
| **Technicals** | `technicals.html` | RSI, MACD, moving averages, support/resistance per ticker |
| **Sentiment** | `sentiment.html` | Sentiment scoring across the universe |
| **Options** | `options.html` | Options activity, IV, put/call ratios |
| **Stress Test** | `stress-test.html` | Scenario stress (rate shocks, capex pullback, model-lab drawdown) |
| **Correlation** | `correlation.html` | Pairwise correlation matrix across tickers |
| **Insider** | `insider.html` | Insider buy/sell activity |
| **News** | `news.html` | Aggregated news feed by ticker |
| **Leaderboard** | `leaderboard.html` | Daily winners/losers, momentum ranking |

The sidebar layout, theme tokens (dark/light), and i18n strings live in `public/dashboard_enhancements.css` (served by dashboard-core), `public/dashboard_enhancements.js` (served by dashboard-core), and `public/i18n.js` respectively. Clicking any ticker chip opens a side panel with live price refresh + sparkline.

---

## Data flow

```
Browser ─┐
         │  GET /api/quote/:symbol     (single, includes intraday candles)
         │  GET /api/quotes?symbols=…  (batch, lightweight)
         │  GET /api/history, /api/options, /api/options-flow, /api/news
         ▼
  server.js ──► dashboard-core ──► Yahoo Finance v8 chart API
                  │
                  └──►  in-memory TtlCache (dynamic TTL, max-age=60 on hit)
```

- `server.js` is a ~20-line wrapper around `createDashboardServer` from dashboard-core. All proxying, validation, caching, and route mounting lives in the shared package.
- **Canonical ticker list** lives inline in `public/index.html` as `const TICKER_DATA = { 'NVDA': { … } }`. The server passes `tickerData: null`, so canonical lookups come from the inline object via the frontend; the API endpoints accept any valid symbol via `?symbols=…`.
- **Editorial fields** (`thesis`, `tags`, `layers`) are authored manually and never overwritten.
- **Live fields** (`price`, `chg`, `chgPct`, `hi52`, `lo52`) are refreshed from Yahoo.

### Refreshing prices

```bash
npm run update-prices         # rewrite live fields in public/index.html
npm run update-prices:dry     # preview without writing
```

These shell out to the `update-prices` bin shipped by dashboard-core. The bin auto-detects the AI schema (`const TICKER_DATA = { … }`) and rewrites only the live fields, line-by-line. Editorial content stays untouched.

---

## Adding tickers

### One-off: a single ticker

1. Edit the `TICKER_DATA` object in `public/index.html`, add a key with editorial fields (`thesis`, `tags`, `layers`, etc.).
2. Run `npm run update-prices` to populate live fields.
3. Reload the page.

### Bulk: MSX seed

The MSX 2026 layer set is bulk-seedable. Run:

```bash
node scripts/seed_msx_tickers.js
```

This fetches name/price/52w from Yahoo for every MSX ticker not already in `TICKER_DATA`, tags it with `msx-2026` + status + sub-bucket (for L7), and inserts into the inline block. Idempotent — skips tickers already present.

To tag pre-existing rows with their MSX layer label:

```bash
node scripts/backfill_msx_metadata.js
```

---

## Project structure

```
ai-supply-chain/
├── server.js                            # ~20-line wrapper around dashboard-core
├── package.json                         # pins dashboard-core via git+tag
├── news_data.json                       # cached news feed
├── public/
│   ├── index.html                       # main view + inline TICKER_DATA + MSX rotation
│   ├── correlation.html, sentiment.html, technicals.html, options.html,
│   ├── stress-test.html, insider.html, news.html, leaderboard.html
│   └── i18n.js                          # translations + lang toggle injection
├── scripts/
│   ├── seed_msx_tickers.js              # bulk-seed MSX 2026 tickers
│   ├── backfill_msx_metadata.js         # tag pre-existing rows with MSX layer
│   └── ci-check.js                      # syntax + runtime smoke checks (CI)
└── .github/workflows/
    └── syntax-check.yml                 # runs ci-check.js on every PR + push to main
```

---

## Continuous integration

Every PR and every push to `main` runs `scripts/ci-check.js`, which:

1. Runs `node --check` (via `new vm.Script`) on every standalone JS file under `public/` and every inline `<script>` block in every `public/*.html` page.
2. Runs a `vm.runInNewContext` smoke on the `TICKER_DATA` literal, asserting at least 50 tickers parse successfully. Catches failures where syntax is valid but the `const` declaration is unreachable (earlier line throws).

The workflow is fast (~5s, no `npm install` needed — uses node stdlib only). Failure modes it catches: missing commas in `TICKER_DATA`, misplaced object-literal syntax in JS files, and any future variant where the inline script can't reach its end.

---

## Configuration

| Env var | Default | Purpose |
|---|---|---|
| `PORT` | `3000` | HTTP port |

No secrets required — Yahoo's `v8/finance/chart` endpoint is unauthenticated. The dashboard-core proxy sets a `User-Agent` to avoid 403s.

---

## Known limitations

- **Yahoo dependency** — the v8 chart endpoint is unofficial and can rate-limit or change without notice. Migration to LSEG/Refinitiv is on the roadmap.
- **Inline ticker data** — `TICKER_DATA` lives inside `index.html`; a future PR could extract to `public/ai_data.json` (matching the `sw_data.json` / `semi_data.json` pattern used by sibling dashboards) and pass it to `createDashboardServer({ tickerData: path })`. Tracked but not yet started.
- **Day-change semantics** — `chgPct` for some tickers shows multi-day moves because Yahoo's `chartPreviousClose` on a `range=1d` chart isn't strictly yesterday's close. Tracked at [doggychip/dashboard-core#6](https://github.com/doggychip/dashboard-core/issues/6).
- **Cache is in-memory** — restarting flushes all quotes.

---

## Sibling dashboards

- [`software-supply-chain`](https://github.com/doggychip/software-supply-chain) — Software value chain
- [`semi-equipment`](https://github.com/doggychip/semi-equipment) — Semiconductor equipment value chain
- [`dashboard-core`](https://github.com/doggychip/dashboard-core) — shared Express server, Yahoo proxy, cache, and `update-prices` CLI

---

## License

MIT
