const express = require('express');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 3000;

// Serve static files
app.use(express.static(path.join(__dirname, 'public')));

// Proxy endpoint for Yahoo Finance quotes
app.get('/api/quote/:ticker', async (req, res) => {
  const { ticker } = req.params;
  const range = req.query.range || '1d';
  const interval = req.query.interval || '5m';

  try {
    const url = `https://query1.finance.yahoo.com/v8/finance/chart/${encodeURIComponent(ticker)}?range=${range}&interval=${interval}`;
    const response = await fetch(url, {
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
