# AI Infrastructure — Full Value Chain Research Dashboard

A self-hosted equity research dashboard covering the **AI infrastructure value chain**: chips and accelerators, networking, foundries, hyperscalers, model labs, and the application layer riding on top. Live prices, technicals, sentiment, options, news, insider activity, correlations, and stress-tests across the full AI universe.

> **Stack:** Node.js + Express server, vanilla HTML/JS, Chart.js, Yahoo Finance v8 chart API.

---

## Quick start

```bash
git clone https://github.com/doggychip/ai-supply-chain.git
cd ai-supply-chain
npm install
npm start
```

Open `http://localhost:3000`. The server fetches live quotes from Yahoo on demand and serves the static dashboard pages from `public/`.

To run on a different port:

```bash
PORT=4000 npm start
```

---

## What's in here

The dashboard is a **multi-page static site** with a shared layout. Each page is a single self-contained HTML file in `public/`.

| Page | File | What it shows |
|---|---|---|
| **Main** | `index.html` | Layer-by-layer AI value-chain view, ticker cards with live price, change, range, thesis text |
| **Technicals** | `technicals.html` | RSI, MACD, moving averages, support/resistance per ticker |
| **Sentiment** | `sentiment.html` | Sentiment scoring across the universe |
| **Options** | `options.html` | Options activity, IV, put/call ratios |
| **Stress Test** | `stress-test.html` | Scenario stress (rate shocks, capex pullback, model-lab drawdown) |
| **Correlation** | `correlation.html` | Pairwise correlation matrix across tickers |
| **Insider** | `insider.html` | Insider buy/sell activity |
| **News** | `news.html` | Aggregated news feed by ticker |
| **Leaderboard** | `leaderboard.html` | Daily winners/losers, momentum ranking |

The sidebar layout, theme tokens (dark/light), and i18n strings are defined in `dashboard_enhancements.css`, `dashboard_enhancements.js`, and `i18n.js` respectively.

---

## Data flow

```
Browser ─┐
         │  GET /api/quote/:symbol
         │  GET /api/quotes?symbols=...
         ▼
   server.js  ──►  Yahoo Finance v8 chart API
         │
         └──►  in-memory cache (60s TTL)
```

- **Canonical ticker list** lives inline in `public/index.html` as `const TICKER_DATA = { 'NVDA': { ... } }`.
- **Editorial fields** (thesis, tags, layer) are authored manually and never overwritten.
- **Live fields** (`price`, `chg`, `chgPct`, `hi52`, `lo52`) are refreshed from Yahoo.

### Refreshing prices manually

```bash
npm run update-prices
```

This runs `scripts/update_prices.js`, which auto-detects the AI schema (`TICKER_DATA = { ... }` style) and rewrites the live fields in `public/index.html` line-by-line. Editorial content stays untouched. Use `--dry-run` to preview:

```bash
node scripts/update_prices.js --dry-run
```

---

## Adding a new ticker

1. Edit the `TICKER_DATA` object in `public/index.html` — add a key with editorial fields (`thesis`, `tags`, `layer`, etc.).
2. Run `npm run update-prices` to populate live fields.
3. Reload the page.

---

## Project structure

```
ai-supply-chain/
├── server.js                     # Express server + Yahoo proxy + cache
├── package.json
├── news_data.json                # cached news feed
├── public/
│   ├── index.html                # main value-chain view + inline TICKER_DATA
│   ├── sentiment.html
│   ├── technicals.html
│   ├── options.html
│   ├── stress-test.html
│   ├── correlation.html
│   ├── insider.html
│   ├── news.html
│   ├── leaderboard.html
│   ├── dashboard_enhancements.css
│   ├── dashboard_enhancements.js
│   └── i18n.js
└── scripts/
    └── update_prices.js          # Yahoo → index.html (AI schema)
```

---

## Configuration

| Env var | Default | Purpose |
|---|---|---|
| `PORT` | `3000` | HTTP port |

No secrets required — Yahoo's `v8/finance/chart` endpoint is unauthenticated. The `User-Agent` header in `server.js` is required to avoid 403s.

---

## Known limitations

- **Yahoo dependency** — the v8 chart endpoint is unofficial and can rate-limit or change without notice. Migration to LSEG/Refinitiv is on the roadmap.
- **Inline ticker data** — `TICKER_DATA` lives inside `index.html`; consider extracting to a JSON file (as `software-supply-chain` does) for easier editing.
- **Cache is in-memory** — restarting flushes all quotes.
- **No tests, no CI**.
- **Heavy code duplication** with sibling repos — extracting shared assets is on the roadmap.

---

## Sibling dashboards

- [`software-supply-chain`](https://github.com/doggychip/software-supply-chain) — Software value chain
- [`semi-equipment`](https://github.com/doggychip/semi-equipment) — Semiconductor equipment value chain

---

## License

MIT
