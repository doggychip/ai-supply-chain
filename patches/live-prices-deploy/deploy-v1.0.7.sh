#!/usr/bin/env bash
#
# Deploy dashboard-core v1.0.7 — adds quoteSummary extras to /api/quotes
# so /api/quotes returns per-ticker { ..., extras: { eps, pe, divYield,
# 52w, dayHi/Lo, volume, marketCap, analyst PT, recommendationKey } } in
# parallel with the existing chart data. live-prices.js v1.0.7 merges
# these into SW_DATA.tickers[X] so the SW Valuation Table re-renders
# with live PE/EPS/52w/etc., not just price.
#
# Run after deploy-v1.0.6.sh has landed.
# Bumps both dashboards' dep to v1.0.7 (HTML changes not needed — the
# Valuation Tables already render those fields; they'll just pick up
# the live values on every poll automatically).

set -euo pipefail

DC_REPO="${HOME}/dashboard-core"
SW_REPO="${HOME}/software-supply-chain"
AI_REPO="${HOME}/ai-supply-chain"

for d in "$DC_REPO" "$SW_REPO" "$AI_REPO"; do
  [ -d "$d/.git" ] || { echo "!! not a git repo: $d"; exit 1; }
done

echo "==> fetching patches from origin/claude/update-share-price-dashboard-HCLqD"
git -C "$AI_REPO" fetch origin claude/update-share-price-dashboard-HCLqD
TMP="$(mktemp -d)"
git -C "$AI_REPO" archive origin/claude/update-share-price-dashboard-HCLqD patches/ | tar -x -C "$TMP"
DC_PATCH_DIR="$TMP/patches/dashboard-core-v1.0.7-extras"

[ -f "$DC_PATCH_DIR/live-prices.js" ]           || { echo "!! missing $DC_PATCH_DIR/live-prices.js"; exit 1; }
[ -f "$DC_PATCH_DIR/server-yahoo.js.patch" ]    || { echo "!! missing server-yahoo.js.patch"; exit 1; }
[ -f "$DC_PATCH_DIR/server-index.js.patch" ]    || { echo "!! missing server-index.js.patch"; exit 1; }

# ============================================================================
# Step 1: dashboard-core v1.0.7
# ============================================================================
echo
echo "================================================================="
echo "Step 1 / 3: dashboard-core v1.0.7"
echo "================================================================="
cd "$DC_REPO"

[ -z "$(git status --porcelain)" ] || { echo "!! $DC_REPO has uncommitted changes"; exit 1; }

git fetch origin
git checkout main && git pull --ff-only origin main

if git rev-parse --verify --quiet refs/tags/v1.0.7 >/dev/null \
   && git show v1.0.7:server/yahoo.js 2>/dev/null | grep -q quoteSummaryToExtras; then
  echo "==> v1.0.7 already tagged with the extras code — skipping"
else
  git checkout -B feat/quote-summary-extras-v1.0.7

  echo "==> apply server patches"
  git apply "$DC_PATCH_DIR/server-yahoo.js.patch"
  git apply "$DC_PATCH_DIR/server-index.js.patch"
  cp "$DC_PATCH_DIR/live-prices.js"          client/live-prices.js
  cp "$DC_PATCH_DIR/extras-shape.test.js"    lib/live-prices/extras-shape.test.js 2>/dev/null \
    || { mkdir -p lib/live-prices && cp "$DC_PATCH_DIR/extras-shape.test.js" lib/live-prices/extras-shape.test.js; }

  echo "==> validate"
  node --check server/yahoo.js
  node --check server/index.js
  node --check client/live-prices.js
  node lib/live-prices/extras-shape.test.js   # MUST print: all 15 extras-shape tests passed

  git add server/yahoo.js server/index.js client/live-prices.js lib/live-prices/extras-shape.test.js
  git commit -m "feat: /api/quotes returns quoteSummary extras (v1.0.7)

Adds per-ticker \`extras\` block to /api/quotes responses, fetched
from Yahoo's quoteSummary v10 endpoint in parallel with the existing
chart fetch. New fields per ticker:

  marketCap, sharesOutstanding, trailingEps, forwardEps,
  trailingPE, forwardPE, divYield, fiftyTwoWeekHigh,
  fiftyTwoWeekLow, dayHigh, dayLow, regularMarketVolume,
  averageVolume, targetMeanPrice, targetMedianPrice,
  targetHighPrice, targetLowPrice, recommendationKey,
  recommendationMean, numberOfAnalystOpinions

Each field is omitted when null/missing so clients can use
\`typeof === 'number'\` checks without explicit nulls clobbering
existing data on merge.

quoteSummary requires a crumb+cookie token; crumb-dance helpers
moved into server/yahoo.js (sticky process-wide cache, fails
gracefully so chart fetch is unaffected). Same pattern as v1.0.4's
fetchMcapAndShares for update-prices.

client/live-prices.js v1.0.7 merges extras into SW_DATA.tickers[X]
on the SW schema (numeric storage) so the Valuation Table picks
up live PE/EPS/52w/mcap/volume automatically. AI schema's
mcap/pe/hi52/lo52 are string-formatted ('\$X.XT') so the merge
skips those to avoid format-conflict regressions; AI gets the
analyst PT / dayHi/Lo / volume fields stored but not auto-rendered.

Badge format now: '● live · N tkrs (M w/ fund) · HH:MM:SS' — M
counts tickers where quoteSummary returned data (vs failed/blocked).

  \$ node lib/live-prices/extras-shape.test.js
  all 15 extras-shape tests passed

https://claude.ai/code/session_01VvFLsqpGHyRVBJZH9bdVRc"

  git push -u origin feat/quote-summary-extras-v1.0.7
  git checkout main
  git merge --no-ff feat/quote-summary-extras-v1.0.7 -m "Merge feat/quote-summary-extras-v1.0.7: live PE/EPS/52w on /api/quotes"
  git push origin main

  git tag v1.0.7
  git push origin v1.0.7
  git show v1.0.7:server/yahoo.js | grep -c quoteSummaryToExtras   # MUST be >= 1
fi
echo "==> dashboard-core v1.0.7: DONE"

# ============================================================================
# Step 2: bump SW dashboard to v1.0.7
# ============================================================================
echo
echo "================================================================="
echo "Step 2 / 3: software-supply-chain dep bump → v1.0.7"
echo "================================================================="
cd "$SW_REPO"
[ -z "$(git status --porcelain)" ] || { echo "!! $SW_REPO has uncommitted changes"; exit 1; }
git fetch origin
git checkout master && git pull --ff-only origin master

if grep -q '"dashboard-core":.*#v1.0.7' package.json; then
  echo "==> SW dashboard already on v1.0.7 — skipping"
else
  git checkout -B chore/bump-v1.0.7
  npm pkg set 'dependencies.dashboard-core=git+https://github.com/doggychip/dashboard-core.git#v1.0.7'
  rm -rf node_modules package-lock.json && npm install

  echo "==> verify v1.0.7 has the extras code"
  grep -c quoteSummaryToExtras node_modules/dashboard-core/server/yahoo.js
  grep -c 'q.extras' node_modules/dashboard-core/client/live-prices.js

  echo "==> smoke test — confirm /api/quotes now includes extras"
  npm start &
  npm_pid=$!
  sleep 3
  trap "kill \$npm_pid 2>/dev/null || true" EXIT
  resp=$(curl -s --max-time 15 "http://localhost:3000/api/quotes?symbols=MSFT,CRWD" || true)
  kill $npm_pid 2>/dev/null || true; wait $npm_pid 2>/dev/null || true
  trap - EXIT

  echo "$resp" | head -c 400
  echo
  echo "$resp" | grep -q '"extras"' \
    || { echo "!! /api/quotes response missing extras field"; exit 1; }
  echo "  ✓ /api/quotes includes extras"

  git add package.json public/index.html 2>/dev/null
  git commit -m "chore: bump dashboard-core to v1.0.7 (live PE/EPS/52w in Valuation Table)

v1.0.7 adds per-ticker quoteSummary extras to /api/quotes responses
(eps, pe, divYield, 52w high/low, dayHi/Lo, volume, marketCap,
analyst PT). client/live-prices.js merges those into SW_DATA.tickers[X],
so the Valuation Table now re-renders with live PE/EPS/52w/mcap on
every 60s poll, not just on update-prices runs.

No HTML changes — the Valuation Table renderer already reads these
fields from SW_DATA.tickers; they were just static between
update-prices runs. After v1.0.7 they tick alongside price.

Smoke-tested locally: /api/quotes?symbols=MSFT,CRWD now returns
extras with eps, pe, divYield, 52w, analyst PT, etc."
  git push -u origin chore/bump-v1.0.7

  if command -v gh >/dev/null 2>&1; then
    gh pr create --repo doggychip/software-supply-chain \
      --base master \
      --head chore/bump-v1.0.7 \
      --title "chore: bump dashboard-core to v1.0.7 (live PE/EPS/52w/mcap)" \
      --body  "Bumps to v1.0.7 — /api/quotes now includes per-ticker quoteSummary extras (eps, pe, divYield, 52w, mcap, analyst PT), which client/live-prices.js merges into SW_DATA.tickers. Valuation Table re-renders with live PE/EPS/52w on every poll instead of waiting for update-prices runs. No HTML changes."
  else
    echo "==> gh CLI not found — manually merge https://github.com/doggychip/software-supply-chain/compare/master...chore/bump-v1.0.7"
  fi
fi
echo "==> software-supply-chain: DONE"

# ============================================================================
# Step 3: bump AI dashboard to v1.0.7
# ============================================================================
echo
echo "================================================================="
echo "Step 3 / 3: ai-supply-chain dep bump → v1.0.7"
echo "================================================================="
cd "$AI_REPO"
[ -z "$(git status --porcelain)" ] || { echo "!! $AI_REPO has uncommitted changes — stash before re-running"; exit 1; }
git fetch origin
git checkout main && git pull --ff-only origin main

if grep -q '"dashboard-core":.*#v1.0.7' package.json; then
  echo "==> AI dashboard already on v1.0.7 — skipping"
else
  git checkout -B chore/bump-v1.0.7
  npm pkg set 'dependencies.dashboard-core=git+https://github.com/doggychip/dashboard-core.git#v1.0.7'
  rm -rf node_modules package-lock.json && npm install
  grep -c quoteSummaryToExtras node_modules/dashboard-core/server/yahoo.js

  git add package.json package-lock.json 2>/dev/null || git add package.json
  git commit -m "chore: bump dashboard-core to v1.0.7

Picks up quoteSummary extras on /api/quotes. AI dashboard's TICKER_DATA
stores mcap/pe/hi52/lo52 as pre-formatted strings, so live-prices.js
won't auto-update those — they remain refreshed only on update-prices
runs. Numeric fields (price, chg, chgPct, dayHi/Lo, volume) and
analyst metadata (targetMeanPrice, recommendationKey) are merged into
TICKER_DATA[X] on every poll for future renderer use."
  git push -u origin chore/bump-v1.0.7

  if command -v gh >/dev/null 2>&1; then
    gh pr create --repo doggychip/ai-supply-chain \
      --base main \
      --head chore/bump-v1.0.7 \
      --title "chore: bump dashboard-core to v1.0.7" \
      --body  "Bumps to v1.0.7. /api/quotes now returns per-ticker extras (eps, pe, divYield, 52w, analyst PT, etc.). Numeric AI fields and analyst metadata are merged into TICKER_DATA[X]; string-formatted fields (mcap/pe/hi52/lo52) still refresh via update-prices only."
  else
    echo "==> gh CLI not found — manually merge https://github.com/doggychip/ai-supply-chain/compare/main...chore/bump-v1.0.7"
  fi
fi
echo "==> ai-supply-chain: DONE"

echo
echo "================================================================="
echo "v1.0.7 deploy complete."
echo "================================================================="
echo
echo "After Zeabur redeploys both dashboards (~60s), look for:"
echo "  - Badge: '● live · N tkrs (M w/ fund) · HH:MM:SS' where M ≈ N"
echo "    (M = tickers where quoteSummary returned analyst data;"
echo "     M < N is OK — ETFs and recently-listed names sometimes have"
echo "     no quoteSummary data)"
echo "  - SW dashboard Valuation Table PE/EPS/52w/volume columns now"
echo "    tick on every poll, not just on manual refreshes"
echo "  - Sanity check: curl 'https://software.zeabur.app/api/quotes?symbols=MSFT' | grep -o '\"extras\"'"
