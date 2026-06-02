# dashboard-core v1.0.5: client-side live-prices polling

## What it adds

A single new file: **`client/live-prices.js`** (~95 lines, no deps).

When loaded by a dashboard, it:

1. Detects the page's data shape (`window.SW_DATA` for the SW schema or
   `window.TICKER_DATA` for the AI schema).
2. Polls `/api/quotes` every 60 seconds (after an initial 800 ms delay so
   first-render finishes first).
3. Merges fresh `price`, `change`, `changePct` (and `previousClose` for SW)
   into the page's data object **in place** — uses the AI schema's
   `chg`/`chgPct` field names when appropriate.
4. Calls each renderer the page registered via
   `(window.dashboardRenderers ||= []).push(fn)` so the DOM updates.
5. Shows a subtle `● live · N tkrs · HH:MM:SS` badge bottom-right;
   greys out to `○ live · offline` when a fetch fails.

Does **not** touch `marketCap` — `/api/quotes` returns chart-derived
data only, no `quoteSummary` lookup. Mcaps continue to come from the
periodic full refresh (`npm run update-prices`).

The server-side endpoint (`app.get('/api/quotes', ...)`) already exists
in dashboard-core; no server changes are needed for v1.0.5.

## Why a new file vs. inlining

Two reasons:
1. The dashboards' static-asset middleware in `createDashboardServer`
   serves `client/*` automatically at the dashboard root — so adding
   `client/live-prices.js` makes it instantly available at `/live-prices.js`
   without any route wiring.
2. The 95 lines are self-contained, no shared state with
   `dashboard_enhancements.js` (different concerns: enhancements does
   search/watchlist/theme; live-prices does data refresh).

## Tests

```
$ node lib/live-prices/merge-isolated.test.js
all 9 merge tests passed
```

Covers both schemas, partial updates, and the `price === 0` guard
(prevents Yahoo's occasional missing-data response from zeroing the UI).

## Apply (in the `doggychip/dashboard-core` repo)

```bash
cd ~/dashboard-core
git checkout main && git pull
git checkout -b feat/live-prices-client

# Drop the new file straight in — it's an ADD, no diff to apply.
mkdir -p client
git -C ~/ai-supply-chain show origin/claude/update-share-price-dashboard-HCLqD:patches/dashboard-core-v1.0.5-live-prices/live-prices.js \
  > client/live-prices.js

# Also drop the offline test so future you can re-validate the merge logic
mkdir -p lib/live-prices
git -C ~/ai-supply-chain show origin/claude/update-share-price-dashboard-HCLqD:patches/dashboard-core-v1.0.5-live-prices/merge-isolated.test.js \
  > lib/live-prices/merge-isolated.test.js

node --check client/live-prices.js                          # MUST be silent
node lib/live-prices/merge-isolated.test.js                 # MUST print: all 9 merge tests passed
git status   # should show 2 new files

git add client/live-prices.js lib/live-prices/merge-isolated.test.js
git commit -m "feat: add client/live-prices.js for runtime price polling"
git push -u origin feat/live-prices-client
# review, merge, tag:
git checkout main && git pull
git tag v1.0.5 && git push origin v1.0.5

# Verify the tag has the new file (MUST print >= 1):
git show v1.0.5:client/live-prices.js | grep -c 'live-prices'
```

## Then in each consuming dashboard

```bash
cd ~/<dashboard>
npm pkg set 'dependencies.dashboard-core=git+https://github.com/doggychip/dashboard-core.git#v1.0.5'
rm -rf node_modules package-lock.json && npm install

# Confirm the script is now served:
ls -la node_modules/dashboard-core/client/live-prices.js
```

The dashboards still need a one-line change to each render IIFE to opt
into live re-renders — that lands in their respective PRs.

## Phase 2 / 3 changes (done separately, repo-by-repo)

Each dashboard's `public/index.html` needs:

1. `<script src="/live-prices.js"></script>` somewhere after
   `dashboard_enhancements.js` (so window.SW_DATA / TICKER_DATA is defined).
2. At the bottom of each render IIFE, one line:
   ```js
   (window.dashboardRenderers = window.dashboardRenderers || []).push(renderFn);
   ```
   where `renderFn` is whatever the IIFE's main render function is named
   (`renderTable`, `renderConviction`, etc.).

That's it. No HTML structural changes; no new DOM hooks. Live prices
flow through the same render path as the initial page load.
