# Deploy software-supply-chain on dashboard-core v1.0.4

Brings `software.zeabur.app` onto the same fixes the AI dashboard just shipped
on PR #20: daily prev-close from the series (v1.0.3) and real `marketCap` from
Yahoo's `quoteSummary` (v1.0.4).

## What it picks up

There's an existing **`origin/use-dashboard-core`** branch in
`doggychip/software-supply-chain` (commit `42aee79`, dated 2026-05-12)
that already did the heavy lifting:

- `server.js`: 401 → 25 lines (thin wrapper around `createDashboardServer`)
- Dropped `node-fetch` dep (native fetch in Node 18+)
- Deleted `public/dashboard_enhancements.{js,css}` (1500+ lines now served
  by dashboard-core's static asset layering)
- Deleted `scripts/update_prices.js` (374-line hand-rolled refresh now
  superseded by the `update-prices` CLI)
- Bumped `engines.node` to `>=18.0.0`

That branch pinned `dashboard-core` at **v1.0.0**, which predates both
our fixes. This deploy bumps the pin **v1.0.0 → v1.0.4** on top of it.

Net diff vs `master`: **+29 / −2263 lines**, plus the price refresh.

## Pre-validated locally

- ✅ Install picks up v1.0.4 with all three patch markers (3/3/3)
- ✅ `server.js` syntax-checks (Zeabur won't fail to boot)
- ✅ Schema auto-detection: `SW_DATA` inline path picked correctly
- ✅ `update-prices` CLI is on PATH via `node_modules/.bin`
- ✅ `npm run update-prices` triggers the sw-schema codepath with the
  three-tier mcap preference (real → price×shares → ratio-scale fallback)

Yahoo itself couldn't be validated from my sandbox (datacenter IP blocked
with `403 Host not in allowlist`), but your Mac IP refreshed 100/106
tickers successfully on the AI dashboard earlier today, so this will too.

## Run

```bash
bash patches/software-supply-chain-deploy-v1.0.4/deploy.sh
# (Defaults to ~/software-supply-chain. Pass a different path as arg 1.)
```

The script auto-aborts if any of:
- Installed `dashboard-core` is missing the v1.0.4 fix (catches the same
  bad-tag mode that bit us on `ai-supply-chain` earlier today)
- `server.js` fails syntax check
- Any ticker has `|changePct| > 50%` (the prev-close-regression guard)

On success it stages the changes and prints the commit/push/PR commands.

## After merge

Zeabur auto-deploys on push to `master`. To verify the live site:
```bash
curl -s https://software.zeabur.app/index.html | grep -m1 "'MSFT':" | grep -oE "marketCap\":[0-9]+"
```
Compare against Yahoo's reported MSFT mcap; should match within rounding.

## Sister: semi-equipment

Same migration applies if `doggychip/semi-equipment` has a similar
hand-rolled refresh script. The pattern is:
1. Check for an existing `use-dashboard-core` branch
2. If yes: bump v1.0.0 → v1.0.4 and refresh
3. If no: build a fresh minimal migration like the original ai-supply-chain
   path (add dashboard-core dep, rewire `update-prices` script, delete
   the hand-rolled script)
