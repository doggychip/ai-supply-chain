#!/usr/bin/env bash
#
# Pre-flight check: does the currently-installed dashboard-core actually
# contain the v1.0.4 real-marketCap fix? If not (e.g. v1.0.4 tag was placed
# on a commit without the fix, or install resolved to a different version),
# `npm run update-prices` will silently fall back to ratio scaling and the
# AMD-style mcap bug will persist.
#
# Run BEFORE `npm run update-prices`. Exits non-zero if the fix is missing.
#
#   bash patches/dashboard-core-v1.0.4-real-mcap/verify-installed.sh
#
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
DC="${ROOT}/node_modules/dashboard-core/lib/update-prices"

if [ ! -d "${DC}" ]; then
  echo "!! dashboard-core not installed. Run: rm -rf node_modules package-lock.json && npm install"
  exit 1
fi

a=$(grep -c fetchMcapAndShares "${DC}/fetch.js" || true)
b=$(grep -c resolveNewMcap     "${DC}/ai-schema.js" || true)
c=$(grep -c "extra.marketCap"  "${DC}/sw-schema.js" || true)

echo "  fetch.js     fetchMcapAndShares : ${a}  (expect >= 2)"
echo "  ai-schema.js resolveNewMcap      : ${b}  (expect >= 2)"
echo "  sw-schema.js extra.marketCap     : ${c}  (expect >= 1)"

if [ "${a}" -ge 2 ] && [ "${b}" -ge 2 ] && [ "${c}" -ge 1 ]; then
  echo "OK — dashboard-core has the v1.0.4 real-mcap fix."
  exit 0
fi

echo
echo "!! Installed dashboard-core is MISSING the v1.0.4 fix."
echo "   update-prices will silently fall back to ratio scaling, perpetuating"
echo "   the AMD/MU/ARM/MRVL mcap drift Codex flagged on PR #20."
echo
echo "   Cause is usually one of:"
echo "     1. The v1.0.4 tag in doggychip/dashboard-core points to a commit"
echo "        without the fix (re-tag on the merged commit and re-install)."
echo "     2. package.json doesn't actually pin v1.0.4 (check with"
echo '          grep dashboard-core package.json'
echo "        and bump if needed)."
echo "     3. node_modules is stale (rm -rf node_modules package-lock.json"
echo "        && npm install)."
exit 1
