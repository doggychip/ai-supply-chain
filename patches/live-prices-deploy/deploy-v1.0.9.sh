#!/usr/bin/env bash
#
# Deploy dashboard-core v1.0.9 — the audit fixes:
#
#   1. /api/quote/:symbol honors ?range=&?interval= (whitelisted) — fixes the
#      AI side panel showing a ~6-month return as the daily change.
#   2. divYield ×100 display fix (SW Valuation Table showed 0.01% for 0.85%).
#   3. Signal shows data coverage (e.g. "82 · 5/6"); <3 components → grey
#      "Low data" instead of Strong/Moderate/Weak.
#   4. Signal adds a 20d momentum component and halves upside-to-PT weight —
#      kills the falling-knife failure mode (a -30% crash now LOWERS the
#      score; v1.0.8 would have raised it). Beat streak no longer
#      double-counts the latest quarter. epsHistory sorted by date.
#   5. Conviction rules: dead 'Profitable' rule dropped; P/E gate becomes a
#      criterion (high-growth names can now qualify); momentum = 20-session
#      return, not one day's move; volume criterion only counts on up days;
#      ties broken by momentum then mcap instead of JSON order.
#
# Steps: dashboard-core tag → SW dashboard (divYield fix + bump + PR).
# The AI dashboard PR is prepared separately via MCP and merged after the
# v1.0.9 tag exists — do NOT merge that PR before running this script.
#
# All 39 offline tests must pass before anything is pushed.

set -euo pipefail

DC_REPO="${HOME}/dashboard-core"
SW_REPO="${HOME}/software-supply-chain"
AI_REPO="${HOME}/ai-supply-chain"

for d in "$DC_REPO" "$SW_REPO"; do
  [ -d "$d/.git" ] || { echo "!! not a git repo: $d"; exit 1; }
done

echo "==> fetching patches from origin/claude/update-share-price-dashboard-HCLqD"
git -C "$AI_REPO" fetch origin claude/update-share-price-dashboard-HCLqD
TMP="$(mktemp -d)"
git -C "$AI_REPO" archive origin/claude/update-share-price-dashboard-HCLqD patches/ | tar -x -C "$TMP"
P="$TMP/patches/dashboard-core-v1.0.9-audit-fixes"
for f in server-index.js.patch server-yahoo.js.patch conviction.js signals.js signals-ui.js signals.test.js; do
  [ -f "$P/$f" ] || { echo "!! missing $P/$f"; exit 1; }
done

# ============================================================================
# Step 1: dashboard-core v1.0.9
# ============================================================================
echo
echo "================================================================="
echo "Step 1 / 2: dashboard-core v1.0.9"
echo "================================================================="
cd "$DC_REPO"
[ -z "$(git status --porcelain)" ] || { echo "!! $DC_REPO dirty — git reset --hard origin/main && git clean -fd"; exit 1; }
git fetch origin
git checkout main && git pull --ff-only origin main

if git rev-parse --verify --quiet refs/tags/v1.0.9 >/dev/null \
   && git show v1.0.9:lib/update-prices/conviction.js 2>/dev/null | grep -q momentum20d; then
  echo "==> v1.0.9 already tagged with the audit fixes — skipping"
else
  git checkout -B fix/audit-v1.0.9
  git apply "$P/server-index.js.patch"
  git apply "$P/server-yahoo.js.patch"
  cp "$P/signals.js"      client/signals.js
  cp "$P/signals-ui.js"   client/signals-ui.js
  cp "$P/conviction.js"   lib/update-prices/conviction.js
  cp "$P/signals.test.js" lib/signals/signals.test.js

  node --check server/index.js
  node --check server/yahoo.js
  node --check client/signals.js
  node --check client/signals-ui.js
  node --check lib/update-prices/conviction.js
  node lib/signals/signals.test.js   # MUST print: all 39 v1.0.9 audit-fix tests passed

  git add server/index.js server/yahoo.js client/signals.js client/signals-ui.js \
          lib/update-prices/conviction.js lib/signals/signals.test.js
  git commit -m "fix: audit fixes — falling-knife bias, coverage gating, conviction rules (v1.0.9)

Findings from a full audit of the assessment logic:

1. /api/quote/:symbol ignored ?range=/&interval= and always fetched
   6mo/1d. The AI side panel requests 1d/5m, then derives prevClose
   with a chartPreviousClose fallback — on 6mo responses that's the
   close from ~6 months ago rendered as the daily change (same class
   of bug as the v1.0.3 update-prices fix). Route now honors
   whitelisted range/interval params.

2. Signal falling-knife bias: upside-to-PT rises when price crashes
   (PTs lag), so a -30% crash RAISED the v1.0.8 score. Fixed by
   halving upside weight (max 10) and adding a 20d-momentum
   component (max 20) from priceHistory using the live price as
   endpoint. Regression test: crash 460→322 now drops the score
   82→71.

3. Beat-streak component no longer includes the latest quarter
   (it was double-counted with the last-Q-beat component).

4. Coverage gating: <3 components → grey 'Low data' label instead of
   Strong/Moderate/Weak — the surviving components are typically the
   bullish-skewed analyst ones. Badge now shows coverage (e.g.
   '82 · 5/6').

5. epsHistory sorted by quarter date server-side AND defensively
   client-side, instead of trusting Yahoo's array order for
   'last quarter'.

6. Conviction rules: dead 'Profitable' rule removed (implied by the
   old P/E gate — every candidate got it); the P/E gate is now a
   criterion so high-growth names can qualify on other merits;
   'momentum' is the 20-session return (>= +5%), not one day's
   changePct; the volume criterion only counts on non-negative days;
   ties break by momentum then mcap instead of JSON insertion order.

  \$ node lib/signals/signals.test.js
  all 39 v1.0.9 audit-fix tests passed

https://claude.ai/code/session_01VvFLsqpGHyRVBJZH9bdVRc"

  git push -u origin fix/audit-v1.0.9
  git checkout main
  git merge --no-ff fix/audit-v1.0.9 -m "Merge fix/audit-v1.0.9: assessment-logic audit fixes"
  git push origin main
  git tag v1.0.9
  git push origin v1.0.9
  git show v1.0.9:lib/update-prices/conviction.js | grep -c momentum20d   # MUST be >= 1
fi
echo "==> dashboard-core v1.0.9: DONE"

# ============================================================================
# Step 2: software-supply-chain — divYield fix + bump
# ============================================================================
echo
echo "================================================================="
echo "Step 2 / 2: software-supply-chain (divYield ×100 + bump v1.0.9)"
echo "================================================================="
cd "$SW_REPO"
[ -z "$(git status --porcelain)" ] || { echo "!! $SW_REPO dirty — git reset --hard origin/master && git clean -fd"; exit 1; }
git fetch origin
git checkout master && git pull --ff-only origin master

if grep -q '"dashboard-core":.*#v1.0.9' package.json; then
  echo "==> SW already on v1.0.9 — skipping"
else
  git checkout -B fix/audit-v1.0.9
  npm pkg set 'dependencies.dashboard-core=git+https://github.com/doggychip/dashboard-core.git#v1.0.9'

  # divYield is stored as a fraction (0.00846 = 0.85%) but was rendered with
  # toFixed(2)+'%' directly, showing "0.01%". Multiply by 100 at render time.
  python3 - public/index.html <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
old = "+'<td>'+(r.divYield>0?fmt(r.divYield,2)+'%':'<span class=\"val-neutral\">&mdash;</span>')+'</td>'"
new = "+'<td>'+(r.divYield>0?fmt(r.divYield*100,2)+'%':'<span class=\"val-neutral\">&mdash;</span>')+'</td>'"
if new in s:
    print("  (divYield fix already present)")
elif old in s:
    s = s.replace(old, new, 1)
    open(p, 'w', encoding='utf-8').write(s)
    print("  divYield render fixed (x100)")
else:
    sys.exit("!! divYield render line not found — inspect public/index.html manually")
PY

  rm -rf node_modules package-lock.json && npm install
  grep -c momentum20d node_modules/dashboard-core/lib/update-prices/conviction.js   # >= 1

  echo "==> smoke: server boots"
  npm start & pid=$!
  sleep 3
  trap "kill $pid 2>/dev/null || true" EXIT
  code=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/)
  kill $pid 2>/dev/null || true; wait $pid 2>/dev/null || true
  trap - EXIT
  [ "$code" = "200" ] || { echo "!! server not 200"; exit 1; }
  echo "  / -> 200"

  git add package.json public/index.html package-lock.json 2>/dev/null || git add package.json public/index.html
  git commit -m "fix: divYield x100 display + dashboard-core v1.0.9 audit fixes

- Valuation Table rendered the stored dividend-yield fraction directly
  (MSFT 0.00846 -> '0.01%'); now multiplied by 100 at render ('0.85%').
- Bumps dashboard-core to v1.0.9: signal falling-knife fix (20d momentum
  component, upside-to-PT halved), coverage-gated labels ('Low data'
  under 3 components, badge shows e.g. '82 · 5/6'), beat-streak
  double-count fix, epsHistory date sort, and rebuilt conviction rules
  (dead rule dropped, P/E gate -> criterion, 20-session momentum,
  direction-aware volume, deterministic tie-breaks).

The conviction list regenerates with the new rules on the next
'npm run update-prices' run."
  git push -u origin fix/audit-v1.0.9

  if command -v gh >/dev/null 2>&1; then
    gh pr create --repo doggychip/software-supply-chain --base master --head fix/audit-v1.0.9 \
      --title "fix: divYield display + dashboard-core v1.0.9 audit fixes" \
      --body "divYield was rendered as a raw fraction ('0.01%' instead of '0.85%') — now x100 at render. Bumps dashboard-core to v1.0.9: falling-knife signal fix (crash now lowers the score), coverage-gated labels, beat-streak double-count fix, epsHistory sort, and rebuilt conviction rules. 39 offline tests pass. Conviction list picks up the new rules on the next update-prices run." \
      || echo "  (gh pr create failed — open the compare URL manually)"
  else
    echo "==> gh not found — open: https://github.com/doggychip/software-supply-chain/compare/master...fix/audit-v1.0.9"
  fi
fi
echo "==> software-supply-chain: DONE"

echo
echo "================================================================="
echo "v1.0.9 deploy complete. Merge the SW PR, then tell Claude the tag"
echo "is up — the AI dashboard PR (side-panel fix + bump) merges via MCP."
echo "================================================================="
