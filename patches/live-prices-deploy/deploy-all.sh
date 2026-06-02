#!/usr/bin/env bash
#
# One-shot deploy: ship live-prices polling across dashboard-core (v1.0.5),
# software-supply-chain, and ai-supply-chain (already on PR #21 — this just
# merges it after the dep is available).
#
# Order is critical and enforced by the script:
#   1. dashboard-core: apply patches → commit → push → tag v1.0.5 → push tag
#   2. software-supply-chain: apply patch → commit → push → open PR
#   3. ai-supply-chain: merge the already-open PR #21
#
# Aborts on the first failure with a clear diagnosis. Each step verifies
# the previous one's result before proceeding.
#
# Usage (run from anywhere; defaults assume sibling clones under $HOME):
#
#   bash deploy-all.sh
#   bash deploy-all.sh --dc ~/dashboard-core --sw ~/software-supply-chain --ai ~/ai-supply-chain
#
# Add --skip-dc / --skip-sw / --skip-ai to redo individual steps.

set -euo pipefail

DC_REPO="${HOME}/dashboard-core"
SW_REPO="${HOME}/software-supply-chain"
AI_REPO="${HOME}/ai-supply-chain"
SKIP_DC=0
SKIP_SW=0
SKIP_AI=0

while [ $# -gt 0 ]; do
  case "$1" in
    --dc) DC_REPO="$2"; shift 2 ;;
    --sw) SW_REPO="$2"; shift 2 ;;
    --ai) AI_REPO="$2"; shift 2 ;;
    --skip-dc) SKIP_DC=1; shift ;;
    --skip-sw) SKIP_SW=1; shift ;;
    --skip-ai) SKIP_AI=1; shift ;;
    *) echo "unknown arg: $1"; exit 1 ;;
  esac
done

for d in "$DC_REPO" "$SW_REPO" "$AI_REPO"; do
  [ -d "$d/.git" ] || { echo "!! not a git repo: $d"; exit 1; }
done

# Source of truth for all the artifacts we'll be applying.
PATCHES="$AI_REPO/patches"
[ -d "$PATCHES" ] || { echo "!! missing $PATCHES — fetch claude/update-share-price-dashboard-HCLqD first"; exit 1; }

DC_PATCH_DIR="$PATCHES/dashboard-core-v1.0.5-live-prices"
SW_PATCH_DIR="$PATCHES/software-supply-chain-live-prices"

# Make sure ai-supply-chain has the handoff branch fetched so we can read
# the patches directory even if the user is on a different branch.
if [ ! -f "$DC_PATCH_DIR/live-prices.js" ]; then
  echo "==> fetching handoff branch in ai-supply-chain"
  git -C "$AI_REPO" fetch origin claude/update-share-price-dashboard-HCLqD
  # Materialize the patches dir into a temp dir from the branch tip
  TMP_PATCHES="$(mktemp -d)"
  git -C "$AI_REPO" archive origin/claude/update-share-price-dashboard-HCLqD patches/ | tar -x -C "$TMP_PATCHES"
  DC_PATCH_DIR="$TMP_PATCHES/patches/dashboard-core-v1.0.5-live-prices"
  SW_PATCH_DIR="$TMP_PATCHES/patches/software-supply-chain-live-prices"
fi

# ============================================================================
# Step 1: dashboard-core v1.0.5
# ============================================================================
if [ "$SKIP_DC" -eq 0 ]; then
  echo
  echo "================================================================="
  echo "Step 1 / 3: dashboard-core v1.0.5"
  echo "================================================================="
  cd "$DC_REPO"

  # Refuse to proceed on a dirty tree
  if [ -n "$(git status --porcelain)" ]; then
    echo "!! $DC_REPO has uncommitted changes — stash or commit before re-running"
    exit 1
  fi

  echo "==> sync main"
  git fetch origin
  git checkout main && git pull --ff-only origin main

  # Early-exit if v1.0.5 already exists with the fix
  if git rev-parse --verify --quiet refs/tags/v1.0.5 >/dev/null \
     && git show v1.0.5:client/live-prices.js 2>/dev/null | grep -q dashboardRenderers; then
    echo "==> v1.0.5 already tagged and contains the fix — skipping dashboard-core step"
  else
    echo "==> branch: feat/live-prices-client"
    git checkout -B feat/live-prices-client

    echo "==> drop in client/live-prices.js + tests"
    mkdir -p client lib/live-prices
    cp "$DC_PATCH_DIR/live-prices.js"          client/live-prices.js
    cp "$DC_PATCH_DIR/merge-isolated.test.js"  lib/live-prices/merge-isolated.test.js

    echo "==> validate"
    node --check client/live-prices.js
    node lib/live-prices/merge-isolated.test.js     # MUST print: all 9 merge tests passed

    git add client/live-prices.js lib/live-prices/merge-isolated.test.js
    git commit -m "feat: add client/live-prices.js for runtime price polling

A ~95-line client-side script that polls /api/quotes every 60s,
mutates SW_DATA.tickers[X] or TICKER_DATA[X] in place, and calls
any render functions the page has registered via
window.dashboardRenderers.

Auto-detects schema (SW vs AI), guards against price=0, leaves
marketCap to update-prices (no quoteSummary in /api/quotes path).
Subtle '● live · N tkrs · HH:MM:SS' badge bottom-right.

Server-side /api/quotes endpoint already existed; no server changes.

  \$ node lib/live-prices/merge-isolated.test.js
  all 9 merge tests passed

https://claude.ai/code/session_01VvFLsqpGHyRVBJZH9bdVRc"

    echo "==> push branch + merge to main"
    git push -u origin feat/live-prices-client
    git checkout main
    git merge --no-ff feat/live-prices-client -m "Merge feat/live-prices-client: add runtime price polling client"
    git push origin main

    echo "==> tag v1.0.5"
    git tag v1.0.5
    git push origin v1.0.5

    echo "==> verify the tag has the client file"
    git show v1.0.5:client/live-prices.js | grep -c dashboardRenderers
    # ^ must be >= 1
  fi

  echo "==> dashboard-core: DONE"
fi

# ============================================================================
# Step 2: software-supply-chain
# ============================================================================
if [ "$SKIP_SW" -eq 0 ]; then
  echo
  echo "================================================================="
  echo "Step 2 / 3: software-supply-chain (wire live-prices.js)"
  echo "================================================================="
  cd "$SW_REPO"

  if [ -n "$(git status --porcelain)" ]; then
    echo "!! $SW_REPO has uncommitted changes — stash or commit before re-running"
    exit 1
  fi

  echo "==> sync master"
  git fetch origin
  git checkout master && git pull --ff-only origin master

  echo "==> branch: chore/live-prices-client"
  git checkout -B chore/live-prices-client

  echo "==> apply patch"
  git apply "$SW_PATCH_DIR/wire-live-prices.patch"

  echo "==> reinstall to pick up dashboard-core v1.0.5"
  rm -rf node_modules package-lock.json
  npm install

  echo "==> pre-flight: confirm dashboard-core v1.0.5 has the client script"
  if [ ! -f node_modules/dashboard-core/client/live-prices.js ]; then
    echo "!! dashboard-core v1.0.5 install is MISSING client/live-prices.js"
    echo "   This usually means step 1 didn't actually tag v1.0.5 with the fix."
    exit 1
  fi
  grep -c dashboardRenderers node_modules/dashboard-core/client/live-prices.js  # >= 1

  echo "==> local smoke test"
  npm start &
  npm_pid=$!
  sleep 3
  trap "kill $npm_pid 2>/dev/null || true" EXIT
  root_code=$(curl -s -o /dev/null -w "%{http_code}"      http://localhost:3000/)
  lp_code=$(curl -s -o /dev/null -w "%{http_code}"        http://localhost:3000/live-prices.js)
  quotes=$(curl -s --max-time 10                          http://localhost:3000/api/quotes | head -c 200 || true)
  kill $npm_pid 2>/dev/null || true
  wait $npm_pid 2>/dev/null || true
  trap - EXIT

  echo "  /                : $root_code"
  echo "  /live-prices.js  : $lp_code"
  echo "  /api/quotes head : $(echo "$quotes" | head -c 100)..."

  [ "$root_code" = "200" ] || { echo "!! root not 200"; exit 1; }
  [ "$lp_code"   = "200" ] || { echo "!! live-prices.js not served"; exit 1; }
  echo "$quotes" | grep -q '"quotes"' || { echo "!! /api/quotes response missing 'quotes' field"; exit 1; }

  echo "==> commit + push"
  git add package.json package-lock.json public/index.html 2>/dev/null || \
    git add package.json public/index.html  # package-lock.json may be gitignored
  git commit -m "feat: wire live-prices.js into SW dashboard (dashboard-core v1.0.5)

Bumps dashboard-core v1.0.4 -> v1.0.5 to pick up client/live-prices.js
(runtime /api/quotes polling that mutates SW_DATA.tickers in place
every 60s) and adds a 6-line refactor to the Valuation Table IIFE so
it picks up fresh prices on each render.

The 4 other SW_DATA-consuming code paths are intentionally untouched:
mini-sparklines use priceHistory (refreshed only by update-prices),
side panel reads SW_DATA fresh on each open, portfolio simulator
uses layer metadata not prices, theme toggle is unrelated.

Subtle '● live · N tkrs · HH:MM:SS' badge bottom-right.

Limitation: marketCap not live-polled (/api/quotes returns chart-only
data; no quoteSummary). Mcaps refresh on npm run update-prices.

Pre-validated locally:
 - dashboard-core v1.0.5 install has client/live-prices.js
 - npm start serves: / -> 200, /live-prices.js -> 200, /api/quotes -> valid JSON
 - Modified IIFE parses without JS syntax errors

https://claude.ai/code/session_01VvFLsqpGHyRVBJZH9bdVRc"

  git push -u origin chore/live-prices-client

  # Try to open a PR via gh; fall back to printing the URL.
  if command -v gh >/dev/null 2>&1; then
    echo "==> opening PR via gh"
    gh pr create --repo doggychip/software-supply-chain \
      --base master \
      --head chore/live-prices-client \
      --title "feat: wire live-prices.js into SW dashboard (dashboard-core v1.0.5)" \
      --body  "Bumps dashboard-core to v1.0.5 (adds client/live-prices.js — runtime /api/quotes polling) and wires it into the Valuation Table IIFE. Bottom-right corner shows ● live · N tkrs · HH:MM:SS. Pre-validated locally: server boots, /live-prices.js serves 200, /api/quotes returns valid JSON. See ai-supply-chain PR #21 for matched changes."
  else
    echo "==> gh CLI not found — open this URL in browser to create PR:"
    echo "    https://github.com/doggychip/software-supply-chain/compare/master...chore/live-prices-client"
  fi

  echo "==> software-supply-chain: DONE"
fi

# ============================================================================
# Step 3: ai-supply-chain (merge already-open PR #21)
# ============================================================================
if [ "$SKIP_AI" -eq 0 ]; then
  echo
  echo "================================================================="
  echo "Step 3 / 3: ai-supply-chain — merge PR #21"
  echo "================================================================="

  if command -v gh >/dev/null 2>&1; then
    state=$(gh pr view 21 --repo doggychip/ai-supply-chain --json state -q .state 2>/dev/null || echo UNKNOWN)
    echo "==> PR #21 state: $state"
    if [ "$state" = "OPEN" ]; then
      echo "==> squash-merging PR #21"
      gh pr merge 21 --repo doggychip/ai-supply-chain --squash
    else
      echo "==> PR #21 is $state — skipping merge"
    fi
  else
    echo "==> gh CLI not found — open this URL to merge manually:"
    echo "    https://github.com/doggychip/ai-supply-chain/pull/21"
  fi

  echo "==> ai-supply-chain: DONE"
fi

echo
echo "================================================================="
echo "All steps complete."
echo "================================================================="
echo
echo "Zeabur will auto-redeploy both dashboards on the new commits."
echo "After ~60s, hard-refresh and look for the ● live badge bottom-right."
echo
echo "If anything looks off, inspect with:"
echo "  curl -s 'https://software.zeabur.app/live-prices.js' | head -c 200"
echo "  curl -s 'https://software.zeabur.app/api/quotes' | head -c 500"
