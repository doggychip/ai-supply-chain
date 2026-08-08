#!/usr/bin/env bash
#
# Deploy v1.0.10 — auto-refresh + momentum staleness guard.
#
#   Step 0: merge SW PR #10 if still open (v1.0.9 divYield + audit fixes)
#   Step 1: dashboard-core v1.0.10 — update-prices stamps SW_DATA.refreshedAt;
#           client signals gate the 20d-momentum component on the stamp being
#           < 14 days old (stale history → component skipped, coverage drops
#           visibly to 5/6 instead of momentum silently measuring months)
#   Step 2: software-supply-chain — refresh-prices.yml workflow (daily 21:30
#           UTC + manual dispatch, sanity-gated) + v1.0.10 bump → PR
#
# The AI dashboard side is PR #26 (already open) — Claude merges it via MCP
# after the tag exists, then triggers the first refresh run.

set -euo pipefail
DC_REPO="${HOME}/dashboard-core"
SW_REPO="${HOME}/software-supply-chain"
AI_REPO="${HOME}/ai-supply-chain"
for d in "$DC_REPO" "$SW_REPO"; do
  [ -d "$d/.git" ] || { echo "!! not a git repo: $d — git clone https://github.com/doggychip/$(basename "$d").git $d"; exit 1; }
done

echo "==> fetching patches"
git -C "$AI_REPO" fetch origin claude/update-share-price-dashboard-HCLqD
TMP="$(mktemp -d)"
git -C "$AI_REPO" archive origin/claude/update-share-price-dashboard-HCLqD patches/ | tar -x -C "$TMP"
P="$TMP/patches/dashboard-core-v1.0.10-staleness"
for f in sw-schema.js signals.js signals.test.js sw-refresh-prices.yml; do
  [ -f "$P/$f" ] || { echo "!! missing $P/$f"; exit 1; }
done

# ── Step 0: SW PR #10 ──
echo
echo "================================================================="
echo "Step 0 / 3: merge SW PR #10 (v1.0.9) if still open"
echo "================================================================="
if command -v gh >/dev/null 2>&1; then
  state=$(gh pr view 10 --repo doggychip/software-supply-chain --json state -q .state 2>/dev/null || echo UNKNOWN)
  echo "PR #10 state: $state"
  if [ "$state" = "OPEN" ]; then gh pr merge 10 --repo doggychip/software-supply-chain --squash; fi
else
  echo "gh not found — merge https://github.com/doggychip/software-supply-chain/pull/10 manually, then re-run"
fi

# ── Step 1: dashboard-core v1.0.10 ──
echo
echo "================================================================="
echo "Step 1 / 3: dashboard-core v1.0.10"
echo "================================================================="
cd "$DC_REPO"
[ -z "$(git status --porcelain)" ] || { echo "!! dirty — git reset --hard origin/main && git clean -fd"; exit 1; }
git fetch origin --tags
git checkout main && git pull --ff-only origin main
if git rev-parse --verify --quiet refs/tags/v1.0.10 >/dev/null \
   && git show v1.0.10:client/signals.js 2>/dev/null | grep -q historyIsFresh; then
  echo "==> v1.0.10 already tagged — skipping"
else
  git checkout -B feat/staleness-guard-v1.0.10
  cp "$P/sw-schema.js"     lib/update-prices/sw-schema.js
  cp "$P/signals.js"       client/signals.js
  cp "$P/signals.test.js"  lib/signals/signals.test.js
  node --check lib/update-prices/sw-schema.js
  node --check client/signals.js
  node lib/signals/signals.test.js   # MUST print: all 44 v1.0.10 tests passed
  git add lib/update-prices/sw-schema.js client/signals.js lib/signals/signals.test.js
  git commit -m "feat: momentum staleness guard (v1.0.10)

update-prices stamps SW_DATA.refreshedAt (YYYY-MM-DD); client signals
gate the 20d-momentum component on the stamp being < 14 days old.
Stale or unstamped history skips the component and drops it from
normalization — staleness becomes visible (coverage 5/6) instead of
momentum silently measuring months when priceHistory hasn't been
refreshed.

  \$ node lib/signals/signals.test.js
  all 44 v1.0.10 tests passed (audit fixes + staleness gate)

https://claude.ai/code/session_01VvFLsqpGHyRVBJZH9bdVRc"
  git push -u origin feat/staleness-guard-v1.0.10
  git checkout main
  git merge --no-ff feat/staleness-guard-v1.0.10 -m "Merge feat/staleness-guard-v1.0.10"
  git push origin main
  git tag v1.0.10 && git push origin v1.0.10
  git show v1.0.10:client/signals.js | grep -c historyIsFresh
fi
echo "==> dashboard-core v1.0.10: DONE"

# ── Step 2: SW workflow + bump ──
echo
echo "================================================================="
echo "Step 2 / 3: software-supply-chain (auto-refresh workflow + v1.0.10)"
echo "================================================================="
cd "$SW_REPO"
[ -z "$(git status --porcelain)" ] || { echo "!! dirty — git reset --hard origin/master && git clean -fd"; exit 1; }
git fetch origin
git checkout master && git pull --ff-only origin master
if grep -q '#v1.0.10' package.json && [ -f .github/workflows/refresh-prices.yml ]; then
  echo "==> SW already deployed — skipping"
else
  git checkout -B feat/auto-refresh-v1.0.10
  mkdir -p .github/workflows
  cp "$P/sw-refresh-prices.yml" .github/workflows/refresh-prices.yml
  npm pkg set 'dependencies.dashboard-core=git+https://github.com/doggychip/dashboard-core.git#v1.0.10'
  rm -rf node_modules package-lock.json && npm install
  grep -c historyIsFresh node_modules/dashboard-core/client/signals.js   # >= 1
  git add .github/workflows/refresh-prices.yml package.json
  git add package-lock.json 2>/dev/null || true
  git commit -m "feat: daily auto-refresh workflow + dashboard-core v1.0.10

refresh-prices.yml runs update-prices on GitHub runners (no Yahoo
geo-block) every weekday 21:30 UTC + manual dispatch, refuses to commit
on any >50% day-change, refreshes BOTH sw_data.json and index.html.
v1.0.10 stamps refreshedAt so the momentum component is gated on
actual data freshness."
  git push -u origin feat/auto-refresh-v1.0.10
  if command -v gh >/dev/null 2>&1; then
    gh pr create --repo doggychip/software-supply-chain --base master --head feat/auto-refresh-v1.0.10 \
      --title "feat: daily auto-refresh + v1.0.10 staleness guard" \
      --body "Adds the scheduled price-refresh workflow (weekdays 21:30 UTC + manual trigger, sanity-gated) and bumps dashboard-core to v1.0.10 (momentum gated on data freshness — stale history shows as reduced coverage instead of mislabeled momentum). Merge, then Actions → refresh-prices → Run workflow for the first refresh." \
      && echo "==> now merge it: gh pr merge --squash --repo doggychip/software-supply-chain \$(gh pr list --repo doggychip/software-supply-chain --head feat/auto-refresh-v1.0.10 --json number -q '.[0].number')"
  fi
fi
echo
echo "================================================================="
echo "Step 3 / 3 is Claude's: say 'tag is up' — PR #26 lockfile + merge,"
echo "then Claude triggers the first AI refresh via the Actions API."
echo "For SW's first refresh after its PR merges:"
echo "  gh workflow run refresh-prices --repo doggychip/software-supply-chain"
echo "================================================================="
