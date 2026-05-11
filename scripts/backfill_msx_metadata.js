// scripts/backfill_msx_metadata.js
// Appends MSX 2026 layer/tags onto TICKER_DATA rows that already existed at seed time.
// Idempotent. Single-line edits, preserves update_prices.js parseability.
// Does NOT touch `thesis` — existing hand-curated thesis is more specific than MSX's.

const fs = require('fs');
const path = require('path');

const INDEX_HTML = path.join(__dirname, '..', 'public', 'index.html');

const LAYERS = {
  L3: { name: 'Chip Architecture & Semi Equipment',  status: 'rotated',     tickers: ['ARM','LRCX','KLAC','AMAT','TER','MKSI','TSEM','ASML','AXTI','VECO','FORM','COHU','AEHR','CLS'] },
  L4: { name: 'Storage & Memory',                    status: 'rotated',     tickers: ['MU','SNDK','WDC','STX'] },
  L5: { name: 'Optical Comms & Networking',          status: 'rotated',     tickers: ['AAOI','LITE','CIEN','FN','LWLG','MRVL','CRDO','ANET','NOK','COHR','GLW','VIAV','MXL','POET','LASR','LPTH'] },
  L6: { name: 'Compute Infra & Data Centers',        status: 'attacking',   tickers: ['VRT','ETN','GEV','IREN','BE','FLNC','EOSE','POWL','AMSC','WOLF','D'] },
  L1: { name: 'Energy & Power Base',                 status: 'heating_up',  tickers: ['NEE','VST','CCJ','URA','XE'] },
  L2: { name: 'Raw Materials & Rare Earths',         status: 'pending',     tickers: ['FCX','ALB','USAR','UUUU','AA','LAC','SGML','CPER'] },
  L7: { name: 'Application · Physical AI',           status: 'front_loaded', sub_buckets: {
    'commercial-space': ['RKLB','LUNR','YSS','RDW','VOYG','VELO'],
    'satellite-intel':  ['ASTS','PL','BKSY','SATL','SATS','MNTS','SIDU','IRDM','VSAT','GSAT'],
    'defense-mapping':  ['LMT','NOC','RTX','HII','KTOS','AVAV','ONDS','SWMR','ITA','XAR','DXYZ','VCX']
  }},
};

// ---------- Build per-ticker MSX metadata map ----------
function buildMsxMap() {
  const map = new Map();
  for (const [layerId, l] of Object.entries(LAYERS)) {
    const layerLabel = `MSX ${layerId}: ${l.name}`;
    const add = (t, extra = []) => map.set(t, { layerLabel, tags: ['msx-2026', l.status, ...extra] });
    if (l.tickers) {
      for (const t of l.tickers) add(t);
    } else if (l.sub_buckets) {
      for (const [bucket, syms] of Object.entries(l.sub_buckets)) {
        for (const t of syms) add(t, [bucket]);
      }
    }
  }
  return map;
}

// ---------- Helpers ----------
const parseArr   = text => [...text.matchAll(/'((?:[^'\\]|\\')*)'/g)].map(m => m[1]);
const formatArr  = arr  => `[${arr.map(s => `'${s.replace(/'/g, "\\'")}'`).join(',')}]`;
const mergeUniq  = (a, b) => { const seen = new Set(), out = []; for (const x of [...a, ...b]) if (!seen.has(x)) { seen.add(x); out.push(x); } return out; };

// ---------- Main ----------
(() => {
  const html   = fs.readFileSync(INDEX_HTML, 'utf8');
  const msxMap = buildMsxMap();
  const rowRe  = /^(\s*)'([A-Z][A-Z0-9._-]*)':\s*\{([^}]*)\},?\s*$/gm;

  let merged = 0, unchanged = 0, malformed = 0;

  const newHtml = html.replace(rowRe, (full, indent, symbol, body) => {
    const msx = msxMap.get(symbol);
    if (!msx) return full;

    const layersMatch = body.match(/layers:\s*\[([^\]]*)\]/);
    const tagsMatch   = body.match(/tags:\s*\[([^\]]*)\]/);
    if (!layersMatch || !tagsMatch) {
      console.warn(`  ! ${symbol.padEnd(6)} missing layers or tags field — skipping`);
      malformed++;
      return full;
    }

    const curLayers = parseArr(layersMatch[1]);
    const curTags   = parseArr(tagsMatch[1]);
    const newLayers = mergeUniq(curLayers, [msx.layerLabel]);
    const newTags   = mergeUniq(curTags, msx.tags);

    const addedL = newLayers.length - curLayers.length;
    const addedT = newTags.length - curTags.length;
    if (addedL === 0 && addedT === 0) {
      console.log(`  · ${symbol.padEnd(6)} already tagged`);
      unchanged++;
      return full;
    }

    // Function replacers — same lesson as update_prices.js fix.
    const newBody = body
      .replace(/layers:\s*\[[^\]]*\]/, () => `layers:${formatArr(newLayers)}`)
      .replace(/tags:\s*\[[^\]]*\]/,   () => `tags:${formatArr(newTags)}`);

    console.log(`  ✓ ${symbol.padEnd(6)} +${addedL} layer, +${addedT} tags`);
    merged++;
    return `${indent}'${symbol}': {${newBody}},`;
  });

  if (merged > 0) {
    fs.writeFileSync(INDEX_HTML, newHtml);
    console.log(`\n✓ Merged MSX metadata into ${merged} ticker(s).`);
  } else {
    console.log(`\n· No changes — ${unchanged} ticker(s) already tagged.`);
  }
  if (malformed > 0) console.log(`⚠ ${malformed} row(s) malformed — see warnings above.`);

  // Sanity check: MSX tickers absent from TICKER_DATA (should be 0 post-seed)
  const present = new Set([...html.matchAll(/^\s*'([A-Z][A-Z0-9._-]*)':\s*\{/gm)].map(m => m[1]));
  const missing = [...msxMap.keys()].filter(t => !present.has(t));
  if (missing.length) console.log(`\n⚠ ${missing.length} MSX tickers missing from TICKER_DATA: ${missing.join(', ')}`);
})();
