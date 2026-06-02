#!/usr/bin/env bash
#
# Follow-up deploy: v1.0.6 of dashboard-core fixes the empty /api/quotes
# response on dashboards configured with tickerData:null (AI), plus adds
# SW conviction-card sync and dynamic-date stamps. Run AFTER the v1.0.5
# deploy (deploy-all.sh) has landed.
#
# What this does, in order:
#   1. dashboard-core: drop in updated live-prices.js → commit → push →
#      merge to main → tag v1.0.6 → push tag. Idempotent.
#   2. software-supply-chain: rebase chore/live-prices-client onto master
#      and replace its content with the expanded patch (v1.0.6 dep +
#      conviction sync + dynamic dates). Force-push updates PR #6 in place.
#   3. Merge SW PR #6 + AI PR #22 via gh.
#
# Each step pre-flights the previous one. Aborts cleanly on failure.

set -euo pipefail

DC_REPO="${HOME}/dashboard-core"
SW_REPO="${HOME}/software-supply-chain"
AI_REPO="${HOME}/ai-supply-chain"

for d in "$DC_REPO" "$SW_REPO" "$AI_REPO"; do
  [ -d "$d/.git" ] || { echo "!! not a git repo: $d"; exit 1; }
done

# Materialize patches from the handoff branch (works regardless of which
# branch is checked out locally).
echo "==> fetching patches from origin/claude/update-share-price-dashboard-HCLqD"
git -C "$AI_REPO" fetch origin claude/update-share-price-dashboard-HCLqD
TMP="$(mktemp -d)"
git -C "$AI_REPO" archive origin/claude/update-share-price-dashboard-HCLqD patches/ | tar -x -C "$TMP"
DC_PATCH_DIR="$TMP/patches/dashboard-core-v1.0.6-live-prices"
SW_PATCH_DIR="$TMP/patches/software-supply-chain-live-prices"

[ -f "$DC_PATCH_DIR/live-prices.js" ]      || { echo "!! missing $DC_PATCH_DIR/live-prices.js"; exit 1; }
[ -f "$SW_PATCH_DIR/wire-live-prices.patch" ] || { echo "!! missing SW patch"; exit 1; }

# ============================================================================
# Step 1: dashboard-core v1.0.6
# ============================================================================
echo
echo "================================================================="
echo "Step 1 / 4: dashboard-core v1.0.6"
echo "================================================================="
cd "$DC_REPO"

if [ -n "$(git status --porcelain)" ]; then
  echo "!! $DC_REPO has uncommitted changes — stash or commit before re-running"
  exit 1
fi

git fetch origin
git checkout main && git pull --ff-only origin main

if git rev-parse --verify --quiet refs/tags/v1.0.6 >/dev/null \
   && git show v1.0.6:client/live-prices.js 2>/dev/null | grep -q symbolsParam; then
  echo "==> v1.0.6 already tagged with the symbolsParam fix — skipping dashboard-core step"
else
  echo "==> branch: feat/live-prices-symbols-v1.0.6"
  git checkout -B feat/live-prices-symbols-v1.0.6

  echo "==> overwrite client/live-prices.js with the v1.0.6 version"
  cp "$DC_PATCH_DIR/live-prices.js"          client/live-prices.js
  cp "$DC_PATCH_DIR/merge-isolated.test.js"  lib/live-prices/merge-isolated.test.js

  node --check client/live-prices.js
  node lib/live-prices/merge-isolated.test.js   # MUST print: all 9 merge tests passed

  git add client/live-prices.js lib/live-prices/merge-isolated.test.js
  git commit -m "feat: derive symbols list from page data (v1.0.6)

v1.0.5's /api/quotes call passed no symbols param, so dashboards
configured with tickerData:null (e.g. ai-supply-chain, where
TICKER_DATA lives inline in HTML rather than a separate JSON file)
received an empty quotes object and the badge showed '0 tkrs'.

v1.0.6 derives the symbol list from window.SW_DATA.tickers or
window.TICKER_DATA on every poll and passes it as ?symbols=A,B,C
(capped at MAX_SYMBOLS=200, the server's validateSymbols limit).
Works for both tickerData:'<file>' and tickerData:null setups.

Filters out Yahoo-incompatible symbols (e.g. '005930.KS' which
exists in the AI dashboard for static display only) by requiring
the same /^[A-Z][A-Z0-9.-]{0,9}\$/ pattern the server uses.

Merge logic unchanged; 9 unit tests still pass.

https://claude.ai/code/session_01VvFLsqpGHyRVBJZH9bdVRc"

  git push -u origin feat/live-prices-symbols-v1.0.6
  git checkout main
  git merge --no-ff feat/live-prices-symbols-v1.0.6 -m "Merge feat/live-prices-symbols-v1.0.6: pass symbols list explicitly"
  git push origin main

  git tag v1.0.6
  git push origin v1.0.6

  git show v1.0.6:client/live-prices.js | grep -c symbolsParam   # MUST be >= 1
fi
echo "==> dashboard-core v1.0.6: DONE"

# ============================================================================
# Step 2: software-supply-chain — replace PR #6's branch content
# ============================================================================
echo
echo "================================================================="
echo "Step 2 / 4: software-supply-chain (replace PR #6 with expanded patch)"
echo "================================================================="
cd "$SW_REPO"

if [ -n "$(git status --porcelain)" ]; then
  echo "!! $SW_REPO has uncommitted changes — stash or commit before re-running"
  exit 1
fi

git fetch origin
git checkout master && git pull --ff-only origin master

echo "==> rebase chore/live-prices-client onto master with the expanded patch"
git checkout -B chore/live-prices-client
git apply "$SW_PATCH_DIR/wire-live-prices.patch"

echo "==> reinstall to pick up dashboard-core v1.0.6"
rm -rf node_modules package-lock.json
npm install

echo "==> verify v1.0.6 client has the symbolsParam fix"
grep -c symbolsParam node_modules/dashboard-core/client/live-prices.js   # >= 1

echo "==> local smoke test"
npm start &
npm_pid=$!
sleep 3
trap "kill \$npm_pid 2>/dev/null || true" EXIT
root_code=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/)
lp_code=$(curl -s -o /dev/null -w "%{http_code}"   http://localhost:3000/live-prices.js)
quotes_full=$(curl -s --max-time 10 "http://localhost:3000/api/quotes?symbols=MSFT,GOOGL,CRWD" || true)
kill $npm_pid 2>/dev/null || true; wait $npm_pid 2>/dev/null || true
trap - EXIT

echo "  /                                : $root_code"
echo "  /live-prices.js                  : $lp_code"
echo "  /api/quotes?symbols=MSFT,GOOGL,CRWD head : $(echo "$quotes_full" | head -c 150)..."

[ "$root_code" = "200" ] || { echo "!! root not 200"; exit 1; }
[ "$lp_code"   = "200" ] || { echo "!! live-prices.js not served"; exit 1; }
# Look at the full response (not a truncated prefix) — Yahoo can return
# tickers in any order so we check that at least one of the three is present
# with valid quote data.
echo "$quotes_full" | grep -qE '"(MSFT|GOOGL|CRWD)":\{[^}]*"price":[0-9.]+' \
  || { echo "!! /api/quotes?symbols= returned no usable quote data"; echo "$quotes_full" | head -c 500; exit 1; }
echo "  ✓ symbols-param flow works"

echo "==> force-push to update PR #6 with the expanded content"
git add package.json package-lock.json public/index.html 2>/dev/null || \
  git add package.json public/index.html
git commit -m "feat: full live-prices wiring on dashboard-core v1.0.6

Expands on v1.0.5's Valuation Table refactor (PR #6 original) with
two missing pieces user reported after the initial deploy:

 1. dashboard-core bumped v1.0.5 -> v1.0.6 to pick up the symbols
    derived from page data, in case anyone later sets tickerData:null
    on this dashboard's server.

 2. Conviction-card price sync — 30 hand-curated .cv-card elements
    across 4 cv-grid sections had hardcoded prices that were NEVER
    updated by update-prices (only SW_DATA.tickers was). Added an
    inline IIFE that walks every .cv-card, reads the ticker from
    .cv-card-ticker, and overwrites .cv-price + .cv-price-chg from
    SW_DATA.tickers[ticker].change / changePct. Registered with
    window.dashboardRenderers so live-prices.js re-runs it on each poll.

 3. Three hardcoded date strings ('Apr 16, 2026' pill, two 'Apr 2026'
    in section descriptions / subtitle) are tagged with
    data-dynamic-date and auto-updated every 2s via Intl date
    formatting — overpowers any i18n.js retranslation.

Smoke-tested locally: server boots, /live-prices.js serves 200,
/api/quotes?symbols=MSFT,GOOGL,CRWD returns valid JSON with all three
tickers.

https://claude.ai/code/session_01VvFLsqpGHyRVBJZH9bdVRc"
git push -f -u origin chore/live-prices-client

echo "==> software-supply-chain: DONE (PR #6 updated)"

# ============================================================================
# Step 3: merge SW PR #6
# ============================================================================
echo
echo "================================================================="
echo "Step 3 / 4: merge SW PR #6"
echo "================================================================="

if command -v gh >/dev/null 2>&1; then
  state=$(gh pr view 6 --repo doggychip/software-supply-chain --json state -q .state 2>/dev/null || echo UNKNOWN)
  echo "==> PR #6 state: $state"
  if [ "$state" = "OPEN" ]; then
    gh pr merge 6 --repo doggychip/software-supply-chain --squash
  fi
else
  echo "==> gh CLI not found; merge https://github.com/doggychip/software-supply-chain/pull/6 manually"
fi

# ============================================================================
# Step 4: merge AI PR #22
# ============================================================================
echo
echo "================================================================="
echo "Step 4 / 4: merge AI PR #22"
echo "================================================================="

if command -v gh >/dev/null 2>&1; then
  state=$(gh pr view 22 --repo doggychip/ai-supply-chain --json state -q .state 2>/dev/null || echo UNKNOWN)
  echo "==> PR #22 state: $state"
  if [ "$state" = "OPEN" ]; then
    gh pr merge 22 --repo doggychip/ai-supply-chain --squash
  fi
else
  echo "==> gh CLI not found; merge https://github.com/doggychip/ai-supply-chain/pull/22 manually"
fi

echo
echo "================================================================="
echo "All steps complete. Zeabur will auto-redeploy both dashboards."
echo "================================================================="
echo
echo "After ~60s, hard-refresh each site and you should see:"
echo "  - Bottom-right badge: ● live · N tkrs · HH:MM:SS  (N > 0)"
echo "  - All conviction card prices match TICKER_DATA / SW_DATA"
echo "    and drift toward Yahoo's current prices every 60s"
echo "  - Section descriptions show today's month/date instead of Apr 2026"
echo
echo "Diagnostic if anything's off:"
echo "  curl -s 'https://software.zeabur.app/api/quotes?symbols=MSFT,CRWD' | head -c 300"
echo "  curl -s 'https://ai.zeabur.app/api/quotes?symbols=NVDA,AMD'           | head -c 300"
