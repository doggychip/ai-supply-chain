// Minimal DOM stub to exercise signals-ui.js render paths without a browser.
// Catches runtime errors in the rendering logic (template strings, null guards).
const fs = require('fs');

// Fake DOM
function makeEl() {
  return {
    id: '', className: '', innerHTML: '', style: {},
    _children: [],
    setAttribute() {}, getAttribute() { return null; },
    addEventListener() {}, appendChild(c) { this._children.push(c); },
    querySelector() { return null; }, querySelectorAll() { return []; },
    scrollIntoView() {},
  };
}
const elements = {};
global.document = {
  readyState: 'complete',
  querySelector(sel) {
    if (sel.includes('content') || sel.includes('main')) return makeEl();
    return null;
  },
  querySelectorAll(sel) {
    if (sel.includes('sb-section')) return [makeEl()];
    if (sel.includes('data-dynamic-date')) return [];
    return [];
  },
  getElementById(id) { return elements[id] || (elements[id] = makeEl()); },
  createElement() { return makeEl(); },
  addEventListener() {},
};
global.window = {
  addEventListener() {},
  dispatchEvent() {},
  // full-data ticker + signal
  SW_DATA: { tickers: {
    MSFT: { price: 460, fundamentals: {
      nextEarningsDate: '2026-07-29', isEarningsDateEstimate: false,
      epsHistory: [
        { period:'-4q', beat:true, epsActual:1.1, epsEstimate:1.0, surprisePct:10 },
        { period:'-3q', beat:true, epsActual:1.25, epsEstimate:1.2, surprisePct:4.2 },
        { period:'-2q', beat:false, epsActual:1.4, epsEstimate:1.45, surprisePct:-3.4 },
        { period:'-1q', beat:true, epsActual:1.6, epsEstimate:1.42, surprisePct:12.7 },
      ],
      forward: { epsGrowthNextY: 22, revGrowthCurrentY: 35 },
      analyst: { recommendationKey:'strong_buy', recommendationMean:1.4, numberOfAnalystOpinions:42, targetMeanPrice:520, revenueGrowth:28, earningsGrowth:35 },
    }},
    // ticker with NO fundamentals — must be skipped gracefully
    XYZ: { price: 10 },
  }},
  CustomEvent: function(){},
};
global.window.tickerSignals = {};

// Load signals.js first (computes signals), then signals-ui.js (renders)
eval(fs.readFileSync('client/signals.js', 'utf8'));
eval(fs.readFileSync('client/signals-ui.js', 'utf8'));

// Manually trigger: recompute signals + render
global.window.recomputeSignals();
console.log('tickerSignals MSFT:', JSON.stringify(global.window.tickerSignals.MSFT));

// Call the renderer by simulating fundamentals-loaded → renderAll is registered
// in dashboardRenderers; invoke them.
let threw = null;
(global.window.dashboardRenderers || []).forEach(fn => { try { fn(); } catch(e){ threw = e; } });
if (threw) { console.error('RENDER THREW:', threw.message); process.exit(1); }

// Inspect the produced table HTML
const wrap = elements['signalsTableWrap'];
const html = wrap ? wrap.innerHTML : '(no wrap)';
console.log('table rendered, length:', html.length);
console.log('contains MSFT row:', html.includes('MSFT'));
console.log('contains signal score 85:', html.includes('>85<') || html.includes('85'));
console.log('skipped XYZ (no fundamentals):', !html.includes('XYZ'));
console.log('contains beat/miss dots:', html.includes('border-radius:50%'));
if (html.includes('MSFT') && html.includes('85')) console.log('SMOKE PASS'); else { console.log('SMOKE FAIL'); process.exit(1); }
