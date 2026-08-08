#!/usr/bin/env bash
# Deploy v1.0.12 — unified evidence scorer (P0) + score-history logging (P1).
#   Step 1: dashboard-core v1.0.12 (canonical score.js, lerp curves, parity-
#           tested client, log-scores bin; 53 tests MUST pass before push)
#   Step 2: SW — assessment-trust.js delegates to the core scorer (its 5
#           pinned tests pass unchanged), workflow logs daily score
#           snapshots, bump. AI side is PR #28 (held), merged via MCP.
set -euo pipefail
DC_REPO="${HOME}/dashboard-core"; SW_REPO="${HOME}/software-supply-chain"; AI_REPO="${HOME}/ai-supply-chain"
for d in "$DC_REPO" "$SW_REPO"; do [ -d "$d/.git" ] || { echo "!! not a git repo: $d"; exit 1; }; done
git -C "$AI_REPO" fetch origin claude/update-share-price-dashboard-HCLqD
TMP="$(mktemp -d)"
git -C "$AI_REPO" archive origin/claude/update-share-price-dashboard-HCLqD patches/ | tar -x -C "$TMP"
P="$TMP/patches/dashboard-core-v1.0.12-unified-scorer"
for f in score.js signals.test.js signals.js signals-ui.js log-scores.js core-package.json sw-unified-scorer.patch; do
  [ -f "$P/$f" ] || { echo "!! missing $P/$f"; exit 1; }; done

echo "== Step 1/2: dashboard-core v1.0.12 =="
cd "$DC_REPO"
[ -z "$(git status --porcelain)" ] || { echo "!! dirty — git reset --hard origin/main && git clean -fd"; exit 1; }
git fetch origin --tags && git checkout main && git pull --ff-only origin main
if git rev-parse -q --verify refs/tags/v1.0.12 >/dev/null \
   && git show v1.0.12:lib/signals/score.js 2>/dev/null | grep -q computeScore; then
  echo "already tagged — skipping"
else
  git checkout -B feat/unified-scorer-v1.0.12
  cp "$P/score.js"        lib/signals/score.js
  cp "$P/signals.test.js" lib/signals/signals.test.js
  cp "$P/signals.js"      client/signals.js
  cp "$P/signals-ui.js"   client/signals-ui.js
  mkdir -p bin && cp "$P/log-scores.js" bin/log-scores.js && chmod +x bin/log-scores.js
  cp "$P/core-package.json" package.json
  node --check lib/signals/score.js && node --check client/signals.js \
    && node --check client/signals-ui.js && node --check bin/log-scores.js
  node lib/signals/signals.test.js   # MUST print: all 53 v1.0.12 tests passed
  git add lib client bin package.json
  git commit -m "feat: unified evidence scorer + score-history logging (v1.0.12)

One canonical scorer (lib/signals/score.js) replaces the divergent
copies in client/signals.js and SW's assessment-trust.js: evidence
framing merged with audited mechanics, piecewise-linear curves
instead of step buckets, client parity-tested against the canonical
module. bin/log-scores.js appends daily score snapshots so the
scorer can eventually be validated against forward returns.

https://claude.ai/code/session_01VvFLsqpGHyRVBJZH9bdVRc"
  git push -u origin feat/unified-scorer-v1.0.12
  git checkout main && git merge --no-ff feat/unified-scorer-v1.0.12 -m "Merge feat/unified-scorer-v1.0.12"
  git push origin main && git tag v1.0.12 && git push origin v1.0.12
fi

echo "== Step 2/2: software-supply-chain =="
cd "$SW_REPO"
[ -z "$(git status --porcelain)" ] || { echo "!! dirty — git reset --hard origin/master && git clean -fd"; exit 1; }
git fetch origin && git checkout master && git pull --ff-only origin master
if grep -q '#v1.0.12' package.json; then
  echo "already deployed — skipping"
else
  git checkout -B feat/unified-scorer-v1.0.12
  git apply "$P/sw-unified-scorer.patch"
  rm -rf node_modules package-lock.json && npm install
  grep -c computeScore node_modules/dashboard-core/lib/signals/score.js
  npm test   # SW's own suite incl. the 5 pinned assessment tests — MUST pass
  git add -A
  git commit -m "feat: delegate to unified evidence scorer + score logging (v1.0.12)

assessment-trust.js keeps its editorial role (legacy-ranking removal,
isFutureDate) but delegates all scoring to dashboard-core's canonical
scorer — its 5 pinned tests pass unchanged against the unified math.
Daily workflow now appends score snapshots to history/scores.jsonl."
  git push -u origin feat/unified-scorer-v1.0.12
  command -v gh >/dev/null && gh pr create --repo doggychip/software-supply-chain \
    --base master --head feat/unified-scorer-v1.0.12 \
    --title "feat: unified evidence scorer + score-history logging (v1.0.12)" \
    --body "assessment-trust.js delegates scoring to dashboard-core's canonical scorer (5 pinned tests pass unchanged); piecewise-linear curves; daily score snapshots to history/scores.jsonl for eventual validation. Companion: ai-supply-chain PR #28." \
    && echo "merge with: gh pr merge --squash --repo doggychip/software-supply-chain \$(gh pr list --repo doggychip/software-supply-chain --head feat/unified-scorer-v1.0.12 --json number -q '.[0].number')"
fi
echo "== done — tell Claude the tag is up; PR #28 merges via MCP =="
