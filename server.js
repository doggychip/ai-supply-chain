const express = require('express');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 3000;

// ── Input validation & fetch hardening ─────────────────────────────
// Tickers: 1–10 chars, leading letter, allow letters/digits/dot/dash (BRK.B, RDS-A).
const TICKER_RE = /^[A-Z][A-Z0-9.-]{0,9}$/;
const FETCH_TIMEOUT_MS = 10000;
const RANGE_ALLOW = new Set(['1d', '5d', '1mo', '3mo', '6mo', '1y', '2y', '5y', 'max']);
const INTERVAL_ALLOW = new Set(['1m', '2m', '5m', '15m', '30m', '60m', '90m', '1h', '1d', '1wk', '1mo']);

function validateTicker(s) {
  if (s == null) throw new Error('ticker required');
  const u = String(s).toUpperCase().trim();
  if (!TICKER_RE.test(u)) throw new Error(`invalid ticker: ${s}`);
  return u;
}

async function fetchWithTimeout(url, opts = {}, ms = FETCH_TIMEOUT_MS) {
  const ctl = new AbortController();
  const t = setTimeout(() => ctl.abort(), ms);
  try {
    return await fetch(url, { ...opts, signal: ctl.signal });
  } finally {
    clearTimeout(t);
  }
}

// Serve static files
app.use(express.static(path.join(__dirname, 'public')));

// Proxy endpoint for Yahoo Finance quotes
app.get('/api/quote/:ticker', async (req, res) => {
  let ticker;
  try {
    ticker = validateTicker(req.params.ticker);
  } catch (err) {
    return res.status(400).json({ error: err.message });
  }
  const range = String(req.query.range || '1d');
  const interval = String(req.query.interval || '5m');
  if (!RANGE_ALLOW.has(range)) return res.status(400).json({ error: `invalid range: ${range}` });
  if (!INTERVAL_ALLOW.has(interval)) return res.status(400).json({ error: `invalid interval: ${interval}` });

  try {
    const url = `https://query1.finance.yahoo.com/v8/finance/chart/${encodeURIComponent(ticker)}?range=${range}&interval=${interval}`;
    const response = await fetchWithTimeout(url, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
      }
    });

    if (!response.ok) {
      return res.status(response.status).json({ error: `Yahoo Finance returned ${response.status}` });
    }

    const data = await response.json();
    res.json(data);
  } catch (err) {
    console.error(`Quote fetch error for ${ticker}:`, err.message);
    res.status(502).json({ error: 'Failed to fetch quote' });
  }
});

// News API endpoint
const NEWS_DATA = require('./news_data.json');
app.get('/api/news', (req, res) => {
  res.json(NEWS_DATA);
});

// Fallback to index.html
app.get('*', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
