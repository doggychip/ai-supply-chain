#!/usr/bin/env node
//
// Offline price applier for the AI dashboard (`const TICKER_DATA = { ... }`).
//
// `npm run update-prices` fetches live quotes from Yahoo, which requires
// outbound network. This script does the same field rewrite but reads quotes
// from a local file instead — so a refresh can be applied in a restricted
// environment, or replayed deterministically from a captured snapshot.
//
// It reuses dashboard-core's exact rewrite logic (rewriteAiLine), so the
// output is identical to what `update-prices` would have written for the
// same numbers — including mcap/pe ratio-scaling and the hi52/lo52 handling.
//
// Usage:
//   node scripts/apply_prices.js <quotes.json|quotes.csv> [--dry-run]
//
// Input formats (only price + prev are required; hi52/lo52 optional):
//   JSON:  { "NVDA": { "price": 207.83, "prev": 196.66, "hi52": 216.83, "lo52": 115.21 }, ... }
//   CSV :  header `ticker,price,prev,hi52,lo52` then one row per ticker
//          (`prevClose` is accepted as an alias for `prev`).

const fs = require('fs');
const path = require('path');
const { rewriteAiLine } = require('dashboard-core/lib/update-prices/ai-schema');

const INDEX_PATH = path.join(__dirname, '..', 'public', 'index.html');
const TICKER_BLOCK_START = /^const TICKER_DATA = \{\s*$/m;
const TICKER_LINE = /^(\s*)'([^']+)':\s*\{\s*(.*)\}\s*,?\s*$/;

function fail(msg) {
  console.error(msg);
  process.exit(1);
}

function parseCsv(text) {
  const rows = text.split(/\r?\n/).map((l) => l.trim()).filter(Boolean);
  if (rows.length < 2) fail('CSV has no data rows.');
  const header = rows[0].split(',').map((h) => h.trim().toLowerCase());
  const idx = (names) => names.map((n) => header.indexOf(n)).find((i) => i >= 0) ?? -1;
  const ti = idx(['ticker', 'symbol']);
  const pi = idx(['price']);
  const vi = idx(['prev', 'prevclose', 'previousclose']);
  const hi = idx(['hi52', 'fiftytwoweekhigh', 'yearhigh']);
  const li = idx(['lo52', 'fiftytwoweeklow', 'yearlow']);
  if (ti < 0 || pi < 0 || vi < 0) {
    fail('CSV header must include at least: ticker, price, prev (or prevClose).');
  }
  const out = {};
  for (const row of rows.slice(1)) {
    const c = row.split(',');
    const ticker = (c[ti] || '').trim();
    if (!ticker) continue;
    const q = { price: parseFloat(c[pi]), prev: parseFloat(c[vi]) };
    if (hi >= 0 && c[hi] != null && c[hi].trim() !== '') q.hi52 = parseFloat(c[hi]);
    if (li >= 0 && c[li] != null && c[li].trim() !== '') q.lo52 = parseFloat(c[li]);
    out[ticker] = q;
  }
  return out;
}

function loadQuotes(file) {
  const text = fs.readFileSync(file, 'utf8');
  const quotes = file.toLowerCase().endsWith('.csv') ? parseCsv(text) : JSON.parse(text);
  // Normalize prevClose -> prev for JSON inputs too.
  for (const q of Object.values(quotes)) {
    if (q.prev == null && q.prevClose != null) q.prev = q.prevClose;
  }
  return quotes;
}

function validQuote(q) {
  return q && typeof q.price === 'number' && !isNaN(q.price) && q.price > 0 &&
         typeof q.prev === 'number' && !isNaN(q.prev) && q.prev > 0;
}

function main() {
  const args = process.argv.slice(2);
  const dryRun = args.includes('--dry-run');
  const file = args.find((a) => !a.startsWith('--'));
  if (!file) fail('Usage: node scripts/apply_prices.js <quotes.json|quotes.csv> [--dry-run]');
  if (!fs.existsSync(file)) fail(`Quotes file not found: ${file}`);

  const quotes = loadQuotes(file);
  const src = fs.readFileSync(INDEX_PATH, 'utf8');
  const lines = src.split('\n');

  let blockStart = -1;
  for (let i = 0; i < lines.length; i++) {
    if (TICKER_BLOCK_START.test(lines[i])) { blockStart = i + 1; break; }
  }
  if (blockStart === -1) fail('Could not find `const TICKER_DATA = {` block in public/index.html.');

  const inFile = new Set(Object.keys(quotes));
  let applied = 0, skippedInvalid = 0;
  const seen = new Set();

  for (let i = blockStart; i < lines.length; i++) {
    if (/^\};/.test(lines[i])) break;
    const m = lines[i].match(TICKER_LINE);
    if (!m) continue;
    const ticker = m[2];
    if (!(ticker in quotes)) continue;
    seen.add(ticker);
    const q = quotes[ticker];
    if (!validQuote(q)) {
      console.warn(`  ✗ ${ticker.padEnd(12)} skipped — needs numeric price>0 and prev>0`);
      skippedInvalid++;
      continue;
    }
    lines[i] = rewriteAiLine(lines[i], q);
    const chgPct = ((q.price - q.prev) / q.prev) * 100;
    console.log(`  ✓ ${ticker.padEnd(12)} $${q.price.toFixed(2)} (${chgPct >= 0 ? '+' : ''}${chgPct.toFixed(2)}%)`);
    applied++;
  }

  const unused = [...inFile].filter((t) => !seen.has(t));
  console.log(`\n${applied} applied, ${skippedInvalid} skipped.`);
  if (unused.length) {
    console.log(`Note: ${unused.length} ticker(s) in the quotes file were not found in TICKER_DATA: ${unused.join(', ')}`);
  }

  if (dryRun) { console.log('Dry run — not writing file.'); return; }
  if (applied === 0) fail('No updates applied — leaving file unchanged.');
  fs.writeFileSync(INDEX_PATH, lines.join('\n'));
  console.log(`Wrote ${INDEX_PATH}`);
}

main();
