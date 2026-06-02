# Wire live-prices.js into software-supply-chain

Companion to the dashboard-core v1.0.5 handoff. Adds the `/live-prices.js`
script tag and a 6-line refactor to the Valuation Table IIFE so it picks up
fresh prices from `/api/quotes` polling.

## Pre-validated locally

- ✅ Patch applies cleanly to current `master` (commit `3f472af`)
- ✅ Modified IIFE parses without JS syntax errors
- ✅ Diff is minimal: 13 insertions, 6 deletions across 2 files
- ✅ Zero CSS changes, zero DOM structural changes
- ✅ The 4 other SW_DATA-consuming code paths (mini-sparklines, side
   panel, portfolio simulator, theme toggle) are left untouched — they
   either use static fields (layer colors, theme prefs) or read SW_DATA
   fresh on each invocation (side panel on click)

## What the patch does

1. **`package.json`**: bumps `dashboard-core` pin v1.0.4 → v1.0.5
2. **`public/index.html`**:
   - Adds `<script src="/live-prices.js"></script>` after `dashboard_enhancements.js`
   - In the Valuation Table IIFE:
     - Wraps the `data = Object.entries(tickers).map(...)` snapshot
       into a `buildData()` function
     - Adds `data = buildData()` at the top of `renderTable()` so each
       render reads the *current* state of `SW_DATA.tickers` (which
       live-prices.js mutates in place)
     - Registers `renderTable` with `(window.dashboardRenderers ||= []).push(renderTable)`

## Apply

**Order matters** — dashboard-core v1.0.5 must be tagged FIRST. If you
apply this patch and push before v1.0.5 exists on dashboard-core, the
Zeabur deploy will fail at `npm install` with "tag not found".

```bash
# 0. Verify dashboard-core v1.0.5 is tagged and contains the fix
cd /tmp && rm -rf v15check && mkdir v15check && cd v15check
echo '{"name":"x","version":"1.0.0","dependencies":{"dashboard-core":"git+https://github.com/doggychip/dashboard-core.git#v1.0.5"}}' > package.json
npm install --silent
test -f node_modules/dashboard-core/client/live-prices.js && \
  echo "OK — v1.0.5 has client/live-prices.js" || \
  echo "FAIL — apply dashboard-core v1.0.5 handoff first, then retry"

# 1. Pull the patch and apply it
cd ~/software-supply-chain
git checkout master && git pull
git checkout -b chore/live-prices-client
git -C ~/ai-supply-chain show \
  origin/claude/update-share-price-dashboard-HCLqD:patches/software-supply-chain-live-prices/wire-live-prices.patch \
  | git apply

# 2. Validate
rm -rf node_modules package-lock.json && npm install
test -f node_modules/dashboard-core/client/live-prices.js && \
  echo "OK — live-prices.js installed" || exit 1
node --check public/index.html 2>&1 || true   # HTML isn't JS, will error; visually inspect instead
git diff --stat   # MUST show 2 files: package.json, public/index.html

# 3. Smoke test locally
npm start &
sleep 2
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:3000/             # MUST be 200
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:3000/live-prices.js  # MUST be 200 (served from node_modules/dashboard-core/client/)
curl -s http://localhost:3000/api/quotes | head -c 300   # MUST be valid JSON with `quotes` field
kill %1

# 4. Push and open PR
git push -u origin chore/live-prices-client
gh pr create --base master \
  --title "feat: wire live-prices.js into SW dashboard (dashboard-core v1.0.5)" \
  --body "Bumps dashboard-core to v1.0.5 and adds 6-line refactor to Valuation Table IIFE so it picks up fresh prices from /api/quotes polling. Bottom-right badge shows ● live · N tkrs · HH:MM:SS. See ai-supply-chain PR #21 for context."
```

## Post-merge behavior

Zeabur auto-deploys. After deploy:

- **Valuation Table** rows show fresh prices that update every 60s
- **Conviction list** (if rendered from `SW_DATA.conviction`) updates via
  the `rebuildConviction` path on `update-prices` runs, not via live polling
  (conviction scoring is based on metrics we don't refresh live)
- **Mini sparklines** remain on `priceHistory` (a 6-month daily series),
  not live — that data only changes when full `update-prices` runs
- **Side panel** continues showing data as-rendered (SW dashboard's side
  panel doesn't do its own live fetch, unlike the AI dashboard's)
- Bottom-right corner: subtle `● live · N tkrs · HH:MM:SS` badge

## Limitations

- `marketCap` is not live-updated (`/api/quotes` only returns chart data,
  no `quoteSummary` lookup). Mcaps refresh only on `npm run update-prices`.
- Outside US market hours, `/api/quotes` returns yesterday's close — the
  badge timestamp keeps ticking but values won't change. This is intended.
- The 60s polling interval is server-side cached (dashboard-core's
  `app.get('/api/quotes')` has a 60s cache), so concurrent browsers
  hitting the same instance share one Yahoo call per minute.

## Rollback

Simple `git revert` on the deploy commit. The v1.0.5 dep is backward-compatible
with v1.0.4 — dashboard-core's v1.0.5 adds files but doesn't change any
existing API.
