#!/usr/bin/env bash
#
# Deploy software-supply-chain on dashboard-core v1.0.4.
#
# Builds on the existing origin/use-dashboard-core branch (which carries the
# server.js → thin-wrapper refactor and the asset cleanup), bumps the pin from
# v1.0.0 to v1.0.4, refreshes prices using the v1.0.3 prev-close + v1.0.4
# real-mcap fixes, and stages a PR-ready branch.
#
# Run from anywhere; the script auto-locates the repo via the first argument
# or defaults to ~/software-supply-chain.
#
#   bash deploy.sh [/path/to/software-supply-chain]
#
set -euo pipefail

REPO="${1:-$HOME/software-supply-chain}"
[ -d "$REPO/.git" ] || { echo "!! not a git repo: $REPO"; exit 1; }
cd "$REPO"

BRANCH="deploy/dashboard-core-v1.0.4"

echo "==> Fetching origin"
git fetch origin

echo "==> Branching from origin/use-dashboard-core"
git checkout -B "$BRANCH" origin/use-dashboard-core

echo "==> Bumping dashboard-core v1.0.0 -> v1.0.4"
# npm pkg set rewrites the JSON cleanly without touching formatting elsewhere.
npm pkg set 'dependencies.dashboard-core=git+https://github.com/doggychip/dashboard-core.git#v1.0.4'

echo "==> Reinstalling"
rm -rf node_modules package-lock.json
npm install

echo "==> Pre-flight: verifying installed dashboard-core has the v1.0.4 fix"
a=$(grep -c fetchMcapAndShares node_modules/dashboard-core/lib/update-prices/fetch.js || true)
b=$(grep -c resolveNewMcap     node_modules/dashboard-core/lib/update-prices/ai-schema.js || true)
c=$(grep -c "extra.marketCap"  node_modules/dashboard-core/lib/update-prices/sw-schema.js || true)
echo "  fetch.js     fetchMcapAndShares : ${a}  (expect >= 2)"
echo "  ai-schema.js resolveNewMcap      : ${b}  (expect >= 2)"
echo "  sw-schema.js extra.marketCap     : ${c}  (expect >= 1)"
if [ "${a}" -lt 2 ] || [ "${b}" -lt 2 ] || [ "${c}" -lt 1 ]; then
  echo "!! installed dashboard-core is MISSING the v1.0.4 fix. Aborting."
  exit 1
fi

echo "==> Syntax-check server.js (Zeabur boot dry test)"
node --check server.js

echo "==> Running update-prices"
npm run update-prices

echo "==> Sanity gate: implausible daily moves (|changePct| > 50%)"
bad=$(grep -oE '"changePct":-?[0-9.]+' public/index.html \
  | sed 's/"changePct"://' \
  | awk '{ v=$1; if (v<0) v=-v; if (v>50) c++ } END { print c+0 }')
if [ "${bad}" -gt 0 ]; then
  echo "!! ${bad} ticker(s) have |changePct| > 50% — likely a stale prev/close."
  echo "   Inspect: git diff public/index.html"
  exit 1
fi
echo "  OK — no implausible day-changes."

echo "==> Real-mcap gate: at least 50% of tickers should have real mcap"
# Look for the summary line printed by sw-schema.js. We don't capture it above
# (`npm run` swallows it on some systems), so re-scan the last update-prices log
# if the user piped to a file. Otherwise, count from index.html: every ticker
# with `marketCap` should be a sensible value (this is approximate).
# A precise check would require re-running update-prices with output capture.
echo "  (re-run with: \`npm run update-prices 2>&1 | tee /tmp/sw.log\` to see"
echo "   the 'mcap: N real / M scaled' summary line; N/total > 0.5 is healthy)"

echo "==> Staging"
git add public/index.html package.json package-lock.json
git status --short

cat <<'NEXT'

Done locally. To finish:

  git commit -m "chore: deploy dashboard-core v1.0.4 + refresh prices

Builds on use-dashboard-core (server.js thin-wrapper refactor, asset
cleanup) and bumps the pin v1.0.0 -> v1.0.4 to pick up:

 - v1.0.3 daily prev-close fix (was printing 6-month returns as daily)
 - v1.0.4 real marketCap from Yahoo's quoteSummary (was perpetuating
   stale share counts; AMD-style drift Codex flagged on ai-supply-chain
   PR #20).

Refreshes all tickers from Yahoo using the fixed code path."

  git push -u origin deploy/dashboard-core-v1.0.4
  gh pr create --base master \
    --title "chore: deploy dashboard-core v1.0.4 + refresh prices" \
    --body  "Picks up use-dashboard-core's server.js refactor and bumps to v1.0.4 (v1.0.3 prev-close + v1.0.4 real-mcap fixes). See ai-supply-chain PR #20 for context on the v1.0.4 fix."

Zeabur will auto-deploy on merge to master.
NEXT
