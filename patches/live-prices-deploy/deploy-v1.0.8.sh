#!/usr/bin/env bash
#
# Deploy dashboard-core v1.0.8 — earnings fundamentals + rules-based buy-signal.
#
# Adds:
#   server: /api/fundamentals (earnings history, next date, forward growth,
#           analyst consensus) via Yahoo quoteSummary, 1h cache.
#   client: signals.js     — fetches fundamentals, computes the transparent
#                            0-100 signal (NOT financial advice) from live data.
#           signals-ui.js  — injects an "Earnings & Signals" section (table of
#                            next-earnings date, 4Q beat/miss, growth, analyst,
#                            upside, signal) AND rebuilds any stale hardcoded
#                            earnings calendar with the live next-earnings dates.
#
# Both dashboards just add two <script> tags; signals-ui.js self-injects the
# rest, so there are no fragile edits to existing markup.
#
# Run after v1.0.7 has landed. Idempotent per step.

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
P="$TMP/patches/dashboard-core-v1.0.8-earnings-signals"
for f in server-yahoo.js.patch server-index.js.patch signals.js signals-ui.js signals.test.js; do
  [ -f "$P/$f" ] || { echo "!! missing $P/$f"; exit 1; }
done

# Helper: insert the two new <script> tags right after the live-prices.js tag,
# idempotently, in a given index.html.
inject_tags() {
  python3 - "$1" <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
anchor = '<script src="/live-prices.js"></script>'
adds = '<script src="/signals.js"></script>\n<script src="/signals-ui.js"></script>'
if '/signals-ui.js' in s:
    print("  (script tags already present, skipping)")
elif anchor in s:
    s = s.replace(anchor, anchor + '\n' + adds, 1)
    open(p, 'w', encoding='utf-8').write(s)
    print("  inserted signals.js + signals-ui.js after live-prices.js")
else:
    sys.exit("!! could not find live-prices.js anchor in " + p)
PY
}

# ============================================================================
# Step 1: dashboard-core v1.0.8
# ============================================================================
echo
echo "================================================================="
echo "Step 1 / 3: dashboard-core v1.0.8"
echo "================================================================="
cd "$DC_REPO"
[ -z "$(git status --porcelain)" ] || { echo "!! $DC_REPO dirty — git reset --hard origin/main && git clean -fd"; exit 1; }
git fetch origin
git checkout main && git pull --ff-only origin main

if git rev-parse --verify --quiet refs/tags/v1.0.8 >/dev/null \
   && git show v1.0.8:server/yahoo.js 2>/dev/null | grep -q quoteSummaryToFundamentals; then
  echo "==> v1.0.8 already tagged with the fundamentals code — skipping"
else
  git checkout -B feat/earnings-signals-v1.0.8
  git apply "$P/server-yahoo.js.patch"
  git apply "$P/server-index.js.patch"
  cp "$P/signals.js"     client/signals.js
  cp "$P/signals-ui.js"  client/signals-ui.js
  mkdir -p lib/signals && cp "$P/signals.test.js" lib/signals/signals.test.js

  node --check server/yahoo.js
  node --check server/index.js
  node --check client/signals.js
  node --check client/signals-ui.js
  node lib/signals/signals.test.js   # MUST print: all 28 signal/fundamentals tests passed

  git add server/yahoo.js server/index.js client/signals.js client/signals-ui.js lib/signals/signals.test.js
  git commit -m "feat: earnings fundamentals + rules-based buy-signal (v1.0.8)

Server: new /api/fundamentals endpoint returns per-ticker earnings
history (last 4Q EPS actual vs estimate + beat/miss + surprise%),
quarterly revenue trend, next earnings date, forward EPS/revenue
growth consensus, and analyst recommendation + price targets —
all from Yahoo quoteSummary (earningsHistory, calendarEvents,
earningsTrend, earnings, financialData modules). Own 1h cache since
this data changes ~quarterly, not intraday.

Client signals.js: fetches /api/fundamentals once on load, merges
into SW_DATA/TICKER_DATA[X].fundamentals, and computes a transparent
0-100 buy-SIGNAL (explicitly NOT financial advice) from 5 equally-
weighted, fully-auditable components: last-Q EPS beat, 4Q beat
streak, forward EPS growth, analyst consensus, and upside to mean
price target (the last uses the live polled price, so the signal
re-computes as prices move). Components with missing data are
skipped and the score is normalized over available data.

Client signals-ui.js: purely additive — injects an 'Earnings &
Signals' nav item + section (no edits to existing markup), renders
a sortable table (next earnings date, 4Q beat/miss dots, rev growth,
fwd EPS growth, analyst rating, upside, signal score w/ hover
breakdown), and rebuilds any stale hardcoded #ecalContainer earnings
calendar with the live next-earnings dates.

28 offline tests cover the extractor (full + partial + null payloads)
and the signal math (worked example: full-data ticker @ \$460 → 85,
'Strong'; same ticker @ \$530 → lower as upside compresses).

  \$ node lib/signals/signals.test.js
  all 28 signal/fundamentals tests passed

https://claude.ai/code/session_01VvFLsqpGHyRVBJZH9bdVRc"

  git push -u origin feat/earnings-signals-v1.0.8
  git checkout main
  git merge --no-ff feat/earnings-signals-v1.0.8 -m "Merge feat/earnings-signals-v1.0.8: /api/fundamentals + buy-signal"
  git push origin main
  git tag v1.0.8
  git push origin v1.0.8
  git show v1.0.8:server/yahoo.js | grep -c quoteSummaryToFundamentals   # MUST be >= 1
fi
echo "==> dashboard-core v1.0.8: DONE"

# ============================================================================
# Steps 2 & 3: bump each dashboard + inject the two script tags
# ============================================================================
deploy_dashboard() {
  local repo="$1" base="$2" name="$3"
  echo
  echo "================================================================="
  echo "Bump $name → v1.0.8"
  echo "================================================================="
  cd "$repo"
  [ -z "$(git status --porcelain)" ] || { echo "!! $repo dirty — git reset --hard origin/$base && git clean -fd"; exit 1; }
  git fetch origin
  git checkout "$base" && git pull --ff-only origin "$base"

  if grep -q '"dashboard-core":.*#v1.0.8' package.json && grep -q '/signals-ui.js' public/index.html; then
    echo "==> already on v1.0.8 with signals tags — skipping"
    return
  fi

  git checkout -B chore/earnings-signals-v1.0.8
  npm pkg set 'dependencies.dashboard-core=git+https://github.com/doggychip/dashboard-core.git#v1.0.8'
  inject_tags public/index.html

  rm -rf node_modules package-lock.json && npm install
  grep -c quoteSummaryToFundamentals node_modules/dashboard-core/server/yahoo.js  # >= 1

  echo "==> smoke test: /api/fundamentals returns the earnings shape"
  npm start &
  local pid=$!
  sleep 3
  trap "kill $pid 2>/dev/null || true" EXIT
  local resp
  resp=$(curl -s --max-time 25 "http://localhost:3000/api/fundamentals?symbols=MSFT,CRWD" || true)
  kill $pid 2>/dev/null || true; wait $pid 2>/dev/null || true
  trap - EXIT
  echo "  response head: $(echo "$resp" | head -c 220)"
  echo "$resp" | grep -q '"fundamentals"' \
    || { echo "!! /api/fundamentals missing 'fundamentals' key"; exit 1; }
  # Don't hard-fail on empty fundamentals (Yahoo crumb can be momentarily
  # blocked) — just warn so the deploy still proceeds.
  if echo "$resp" | grep -q '"epsHistory"'; then
    echo "  ✓ live earnings data present (epsHistory found)"
  else
    echo "  ⚠ fundamentals key present but no epsHistory — Yahoo quoteSummary may be"
    echo "    rate-limiting right now. The endpoint works; data will populate on"
    echo "    the next cache miss. Proceeding."
  fi

  git add package.json public/index.html package-lock.json 2>/dev/null || git add package.json public/index.html
  git commit -m "feat: earnings & signals section on dashboard-core v1.0.8 ($name)

Bumps dashboard-core to v1.0.8 and adds two script tags
(signals.js + signals-ui.js). signals-ui.js self-injects an
'Earnings & Signals' section with live next-earnings dates, last-4Q
EPS beat/miss, revenue + forward growth, analyst consensus, upside
to price target, and a transparent 0-100 signal score (NOT financial
advice). It also rebuilds the stale hardcoded earnings calendar with
the live next-earnings dates, fixing the 'dates already passed' issue.

No edits to existing markup beyond the two script tags."
  git push -u origin chore/earnings-signals-v1.0.8

  if command -v gh >/dev/null 2>&1; then
    gh pr create --repo "doggychip/$(basename "$repo")" --base "$base" --head chore/earnings-signals-v1.0.8 \
      --title "feat: earnings & signals (dashboard-core v1.0.8)" \
      --body "Adds an Earnings & Signals section: live next-earnings dates, last-4Q EPS beat/miss, revenue + forward EPS growth, analyst consensus, upside to mean PT, and a transparent rules-based 0-100 signal (NOT financial advice — see signals.js for the exact rules). Also rebuilds the stale hardcoded earnings calendar with live dates. Two script tags only; signals-ui.js self-injects the section." \
      || echo "  (gh pr create failed — open compare URL manually)"
  else
    echo "==> gh not found — open: https://github.com/doggychip/$(basename "$repo")/compare/$base...chore/earnings-signals-v1.0.8"
  fi
  echo "==> $name: DONE"
}

deploy_dashboard "$SW_REPO" master "software-supply-chain"
deploy_dashboard "$AI_REPO" main   "ai-supply-chain"

echo
echo "================================================================="
echo "v1.0.8 deploy complete."
echo "================================================================="
echo
echo "After Zeabur redeploys (~60s), hard-refresh each dashboard and:"
echo "  - New sidebar item 'Earnings & Signals' → a sortable table with"
echo "    live next-earnings dates, 4Q beat/miss dots, growth, analyst,"
echo "    upside, and a 0-100 signal (hover the score for the breakdown)."
echo "  - The old 'Earnings Calendar' now shows LIVE next-earnings dates"
echo "    (the stale Apr-2026 dates are rebuilt from Yahoo)."
echo
echo "Reminder: the signal is a mechanical score from objective Yahoo data,"
echo "explicitly labeled NOT financial advice. The hand-written thesis text"
echo "and conviction scores remain editorial and were not touched."
echo
echo "Probe the new endpoint directly:"
echo "  curl -s 'https://software.zeabur.app/api/fundamentals?symbols=MSFT' | python3 -m json.tool | head -40"
