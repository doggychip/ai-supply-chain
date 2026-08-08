#!/usr/bin/env bash
# Deploy v1.0.11 — corporate-actions accuracy fixes from the value-chain-map audit.
#   Step 1: dashboard-core v1.0.11 (conviction + update-prices skip acquired/delisted; 46 tests)
#   Step 2: SW dashboard patch — CYBR/CFLT marked acquired in BOTH data sources
#           (verified: PANW closed 2026-02-11, IBM closed 2026-03-17), map chips get
#           struck-through † badges with tooltips, side panel shows "no longer
#           publicly traded" instead of a frozen price, editorialAsOf stamps.
#           Built ON TOP of PR #13's fail-closed layer — does not touch it.
#   AI side is PR #27 (held); Claude merges it after the tag.
set -euo pipefail
DC_REPO="${HOME}/dashboard-core"; SW_REPO="${HOME}/software-supply-chain"; AI_REPO="${HOME}/ai-supply-chain"
for d in "$DC_REPO" "$SW_REPO"; do [ -d "$d/.git" ] || { echo "!! not a git repo: $d"; exit 1; }; done
git -C "$AI_REPO" fetch origin claude/update-share-price-dashboard-HCLqD
TMP="$(mktemp -d)"
git -C "$AI_REPO" archive origin/claude/update-share-price-dashboard-HCLqD patches/ | tar -x -C "$TMP"
P="$TMP/patches/dashboard-core-v1.0.11-corporate-actions"
for f in conviction.js sw-schema.js signals.test.js sw-corporate-actions.patch; do
  [ -f "$P/$f" ] || { echo "!! missing $P/$f"; exit 1; }; done

echo "== Step 1/2: dashboard-core v1.0.11 =="
cd "$DC_REPO"
[ -z "$(git status --porcelain)" ] || { echo "!! dirty — git reset --hard origin/main && git clean -fd"; exit 1; }
git fetch origin --tags && git checkout main && git pull --ff-only origin main
if git rev-parse -q --verify refs/tags/v1.0.11 >/dev/null \
   && git show v1.0.11:lib/update-prices/conviction.js 2>/dev/null | grep -q "status === 'acquired'"; then
  echo "already tagged — skipping"
else
  git checkout -B fix/corporate-actions-v1.0.11
  cp "$P/conviction.js" lib/update-prices/conviction.js
  cp "$P/sw-schema.js"  lib/update-prices/sw-schema.js
  cp "$P/signals.test.js" lib/signals/signals.test.js
  node --check lib/update-prices/conviction.js && node --check lib/update-prices/sw-schema.js
  node lib/signals/signals.test.js   # MUST print: all 46 v1.0.11 tests passed
  git add -A lib
  git commit -m "fix: skip acquired/delisted tickers in conviction + update-prices (v1.0.11)

CYBR merged into Palo Alto Networks 2026-02-11; CFLT acquired by IBM
2026-03-17 (both delisted, verified via SEC/press). Tickers marked
status:'acquired'/'delisted' are now excluded from conviction
candidacy and skipped by the update-prices fetch loop.

https://claude.ai/code/session_01VvFLsqpGHyRVBJZH9bdVRc"
  git push -u origin fix/corporate-actions-v1.0.11
  git checkout main && git merge --no-ff fix/corporate-actions-v1.0.11 -m "Merge fix/corporate-actions-v1.0.11"
  git push origin main && git tag v1.0.11 && git push origin v1.0.11
fi

echo "== Step 2/2: software-supply-chain =="
cd "$SW_REPO"
[ -z "$(git status --porcelain)" ] || { echo "!! dirty — git reset --hard origin/master && git clean -fd"; exit 1; }
git fetch origin && git checkout master && git pull --ff-only origin master
if grep -q '#v1.0.11' package.json; then
  echo "already deployed — skipping"
else
  git checkout -B fix/corporate-actions-v1.0.11
  git apply "$P/sw-corporate-actions.patch"
  rm -rf node_modules package-lock.json && npm install
  grep -c "status === 'acquired'" node_modules/dashboard-core/lib/update-prices/conviction.js
  npm start & pid=$!; sleep 3
  trap "kill $pid 2>/dev/null || true" EXIT
  code=$(curl -s -o /dev/null -w '%{http_code}' http://localhost:3000/)
  kill $pid 2>/dev/null || true; wait $pid 2>/dev/null || true; trap - EXIT
  [ "$code" = "200" ] || { echo "!! server not 200"; exit 1; }
  git add -A
  git commit -m "fix: mark CYBR/CFLT acquired + editorial freshness stamps (v1.0.11)

CYBR -> Palo Alto Networks (closed 2026-02-11), CFLT -> IBM (closed
2026-03-17); both delisted but were shown as live stocks with frozen
prices. Now: status fields in both data sources, struck-through †
chips with tooltips everywhere they render, side panel shows the
acquisition instead of a price, and thesis text carries an
'editorial commentary as of' stamp (amber past 60 days).
Built on top of the #13 fail-closed layer. dashboard-core v1.0.11
excludes acquired names from conviction + refresh fetches."
  git push -u origin fix/corporate-actions-v1.0.11
  command -v gh >/dev/null && gh pr create --repo doggychip/software-supply-chain \
    --base master --head fix/corporate-actions-v1.0.11 \
    --title "fix: mark CYBR/CFLT acquired + editorial freshness (v1.0.11)" \
    --body "CYBR and CFLT are delisted (PANW 2026-02-11, IBM 2026-03-17 — SEC/press verified) but were displayed as live stocks with frozen prices. This marks them acquired in both data sources, decorates every chip, fixes the side panel, and adds editorial-freshness stamps. Complements PR #13's fail-closed layer." \
    && echo "merge with: gh pr merge --squash --repo doggychip/software-supply-chain \$(gh pr list --repo doggychip/software-supply-chain --head fix/corporate-actions-v1.0.11 --json number -q '.[0].number')"
fi
echo "== done — tell Claude the tag is up; PR #27 merges via MCP =="
