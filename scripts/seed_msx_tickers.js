// scripts/seed_msx_tickers.js
// Bulk-seeds MSX AI supply chain tickers into TICKER_DATA in public/index.html.
// Fetches name/price/52w from Yahoo Finance via the v8 chart endpoint.
// (The v10 quoteSummary endpoint is auth-gated — 401 "Invalid Crumb" without
// a cookie+crumb pair — so mcap/pe are not recoverable here and are left as
// '—' placeholders. update_prices.js scales those by price ratio over time,
// but only for non-skeleton rows.)
// Idempotent: skips tickers already present.
// Falls back to a skeleton row (price:0) when Yahoo fails. NOTE: update_prices.js
// skips price:0 rows by design, so skeleton rows are NOT auto-healed; failed
// tickers must be backfilled or removed manually.

const fs = require('fs');
const path = require('path');

const INDEX_HTML = path.join(__dirname, '..', 'public', 'index.html');
const USER_AGENT =
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 ' +
  '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

// ---------- MSX 2026 AI supply chain (84 tickers across 7 layers) ----------
const LAYERS = {
  L3: { name: 'Chip Architecture & Semi Equipment',  thesis: '算力定价权 · 第一轮收益',         status: 'rotated',     tickers: ['ARM','LRCX','KLAC','AMAT','TER','MKSI','TSEM','ASML','AXTI','VECO','FORM','COHU','AEHR','CLS'] },
  L4: { name: 'Storage & Memory',                    thesis: 'HBM供给瓶颈 · 存储超级周期',        status: 'rotated',     tickers: ['MU','SNDK','WDC','STX'] },
  L5: { name: 'Optical Comms & Networking',          thesis: '数据中心高速公路 · 800G/1.6T需求爆发', status: 'rotated',  tickers: ['AAOI','LITE','CIEN','FN','LWLG','MRVL','CRDO','ANET','NOK','COHR','GLW','VIAV','MXL','POET','LASR','LPTH'] },
  L6: { name: 'Compute Infra & Data Centers',        thesis: '资金当前最集中战场 · 电力/算力/散热',   status: 'attacking',   tickers: ['VRT','ETN','GEV','IREN','BE','FLNC','EOSE','POWL','AMSC','WOLF','D'] },
  L1: { name: 'Energy & Power Base',                 thesis: '核电/清洁能源 · 10年级别长线',        status: 'heating_up',  tickers: ['NEE','VST','CCJ','URA','XE'] },
  L2: { name: 'Raw Materials & Rare Earths',         thesis: '供给瓶颈 · 最难被替代',              status: 'pending',     tickers: ['FCX','ALB','USAR','UUUU','AA','LAC','SGML','CPER'] },
  L7: { name: 'Application · Physical AI',           thesis: '太空·国防·卫星·映射工具',           status: 'front_loaded', sub_buckets: {
    'commercial-space': ['RKLB','LUNR','YSS','RDW','VOYG','VELO'],
    'satellite-intel':  ['ASTS','PL','BKSY','SATL','SATS','MNTS','SIDU','IRDM','VSAT','GSAT'],
    'defense-mapping':  ['LMT','NOC','RTX','HII','KTOS','AVAV','ONDS','SWMR','ITA','XAR','DXYZ','VCX']
  }},
};

// ---------- Flatten layer structure into a per-ticker list ----------
function flatten() {
  const out = [];
  for (const [layerId, l] of Object.entries(LAYERS)) {
    const layerLabel = `MSX ${layerId}: ${l.name}`;
    if (l.tickers) {
      for (const t of l.tickers) out.push({ symbol: t, layerLabel, thesis: l.thesis, tags: ['msx-2026', l.status] });
    } else if (l.sub_buckets) {
      for (const [bucket, syms] of Object.entries(l.sub_buckets)) {
        for (const t of syms) out.push({ symbol: t, layerLabel, thesis: l.thesis, tags: ['msx-2026', l.status, bucket] });
      }
    }
  }
  return out;
}

// ---------- Yahoo Finance fetch (chart endpoint, unauthenticated) ----------
async function fetchYahoo(symbol) {
  const url =
    `https://query1.finance.yahoo.com/v8/finance/chart/${encodeURIComponent(symbol)}` +
    `?range=1d&interval=5m`;
  const res = await fetch(url, { headers: { 'User-Agent': USER_AGENT } });
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  const j = await res.json();
  const r = j.chart?.result?.[0];
  if (!r) {
    const err = j.chart?.error;
    throw new Error(err ? `${err.code}: ${err.description}` : 'no data');
  }
  const m = r.meta;
  if (typeof m?.regularMarketPrice !== 'number') throw new Error('no regularMarketPrice');
  const prev = typeof m.previousClose === 'number' ? m.previousClose : m.chartPreviousClose;
  if (typeof prev !== 'number' || prev === 0) throw new Error('no previousClose');
  const price = m.regularMarketPrice;
  const chg = price - prev;
  const chgPct = (chg / prev) * 100;
  return {
    name:   (m.shortName || m.longName || symbol).slice(0, 60),
    price,
    chg,
    chgPct,
    mcap:   '—', // chart endpoint does not return marketCap
    pe:     '—', // chart endpoint does not return trailingPE
    hi52:   typeof m.fiftyTwoWeekHigh === 'number' ? `$${m.fiftyTwoWeekHigh.toFixed(2)}` : '—',
    lo52:   typeof m.fiftyTwoWeekLow  === 'number' ? `$${m.fiftyTwoWeekLow.toFixed(2)}`  : '—',
  };
}

// ---------- Build one-line TICKER_DATA entry (regex-parseable) ----------
const esc = s => String(s).replace(/'/g, "\\'");
function buildLine(symbol, data, meta) {
  return `  '${symbol}': { name:'${esc(data.name)}', price:${Number(data.price).toFixed(2)}, chg:${Number(data.chg).toFixed(2)}, chgPct:${Number(data.chgPct).toFixed(2)}, mcap:'${data.mcap}', pe:'${data.pe}', hi52:'${data.hi52}', lo52:'${data.lo52}', layers:['${esc(meta.layerLabel)}'], thesis:'${esc(meta.thesis)}', tags:[${meta.tags.map(t => `'${esc(t)}'`).join(',')}] },`;
}

// ---------- Main ----------
(async () => {
  let html = fs.readFileSync(INDEX_HTML, 'utf8');
  const items = flatten();
  console.log(`MSX seed: ${items.length} tickers across 7 layers.`);

  const existing = new Set([...html.matchAll(/^\s*'([A-Z][A-Z0-9._-]*)':\s*\{/gm)].map(m => m[1]));
  console.log(`TICKER_DATA currently has ${existing.size} tickers.`);

  const toAdd = items.filter(i => !existing.has(i.symbol));
  const skipped = items.filter(i => existing.has(i.symbol)).map(i => i.symbol);
  console.log(`Adding ${toAdd.length} new, skipping ${skipped.length} already present: ${skipped.join(', ')}\n`);

  const newLines = [];
  const failed = [];

  for (const item of toAdd) {
    process.stdout.write(`  ${item.symbol.padEnd(6)} `);
    try {
      const data = await fetchYahoo(item.symbol);
      newLines.push(buildLine(item.symbol, data, item));
      console.log(`✓ ${data.name} @ $${data.price.toFixed(2)}`);
    } catch (e) {
      const skeleton = { name: item.symbol, price: 0, chg: 0, chgPct: 0, mcap: '—', pe: '—', hi52: '—', lo52: '—' };
      newLines.push(buildLine(item.symbol, skeleton, item));
      failed.push({ symbol: item.symbol, error: e.message });
      console.log(`✗ ${e.message} (skeleton inserted)`);
    }
    await new Promise(r => setTimeout(r, 250));
  }

  // Find TICKER_DATA closing `};` and insert before it
  const openIdx = html.indexOf('const TICKER_DATA = {');
  if (openIdx === -1) throw new Error('Could not find `const TICKER_DATA = {`');
  const closeMatch = html.slice(openIdx).match(/\n\s*\};/);
  if (!closeMatch) throw new Error('Could not find TICKER_DATA closing `};`');
  const closeIdx = openIdx + closeMatch.index;

  const today = new Date().toISOString().slice(0, 10);
  const block = `\n  // ---- MSX 2026 AI supply chain seed (${today}) ----\n${newLines.join('\n')}`;

  // Defensive: ensure the previously-last entry has a trailing comma. JS object
  // literals make the last entry's trailing comma optional, so historical "last"
  // entries often lack one. Inserting new entries after a missing-comma line
  // produces `} '<KEY>':` adjacency → SyntaxError. See ai-supply-chain#7 — this
  // exact bug shipped to main once before (PR #4 → fixed by PR #8).
  const before = html.slice(0, closeIdx);
  const lastChar = before.replace(/\s+$/, '').slice(-1);
  const needsComma = lastChar !== ',' && lastChar !== '{';
  if (needsComma) console.log(`  (inserting defensive comma — previously-last entry lacked one)`);
  const safeBlock = needsComma ? ',' + block : block;
  fs.writeFileSync(INDEX_HTML, before + safeBlock + html.slice(closeIdx));

  console.log(`\n✓ Inserted ${newLines.length} entries into TICKER_DATA.`);
  if (failed.length) {
    console.log(`\n⚠ Yahoo fetch failed for ${failed.length} — skeleton rows inserted (NOT auto-healed by update_prices.js — backfill manually):`);
    failed.forEach(f => console.log(`    ${f.symbol}: ${f.error}`));
  }
})().catch(e => { console.error(e); process.exit(1); });
