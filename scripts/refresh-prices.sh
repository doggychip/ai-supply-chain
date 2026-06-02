#!/usr/bin/env bash
#
# Turnkey price refresh for the AI dashboard.
#
# Bumps dashboard-core to a given tag (default v1.0.3 — the daily-prev-close
# fix), installs, previews, refreshes public/index.html, runs a sanity gate
# that blocks the 6-month-return bug from shipping again, and stages the result.
#
# Run from anywhere inside the repo, on a machine WITH Yahoo access
# (not the restricted CI sandbox).
#
#   scripts/refresh-prices.sh [vX.Y.Z]      # default: v1.0.3
#
set -euo pipefail

TAG="${1:-v1.0.3}"
ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

echo "==> Bumping dashboard-core to ${TAG}"
npm pkg set "dependencies.dashboard-core=git+https://github.com/doggychip/dashboard-core.git#${TAG}"
npm install

echo "==> Dry-run preview"
npm run update-prices:dry | head -25

echo "==> Writing public/index.html"
npm run update-prices

echo "==> Sanity gate: implausible daily moves (|chgPct| > 50%)"
bad=$(grep -oE "chgPct:-?[0-9.]+" public/index.html \
  | sed 's/chgPct://' \
  | awk '{ v=$1; if (v<0) v=-v; if (v>50) c++ } END { print c+0 }')
if [ "${bad}" -gt 0 ]; then
  echo "!! ${bad} ticker(s) have |chgPct| > 50% — likely a stale prev/close."
  echo "   This is the symptom the v1.0.3 fix addresses; NOT staging."
  echo "   Confirm you are on dashboard-core >= v1.0.3, then inspect: git diff public/index.html"
  exit 1
fi
echo "   OK — no implausible day-changes."

echo "==> Staging"
git add public/index.html package.json package-lock.json 2>/dev/null || \
  git add public/index.html package.json
echo
echo "Done. Review:  git diff --cached --stat"
echo "Commit/push:   git commit -m 'chore: refresh dashboard prices' && git push"
