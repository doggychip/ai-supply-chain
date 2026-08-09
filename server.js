// Configure dashboard-core's Yahoo proxy and add issuer-filed SEC data.

const express = require('express');
const path = require('path');
const { createDashboardServer } = require('dashboard-core');
const { loadIssuerData } = require('./issuer-data');
const universe = require('./public/universe.json');

const coreApp = createDashboardServer({
  publicDir: path.join(__dirname, 'public'),
  tickerData: path.join(__dirname, 'public', 'universe.json'),
  dashboardName: 'AI Supply Chain',
});

const app = express();
const ACTIVE_SYMBOLS = new Set(Object.keys(universe.tickers));
const EXCLUDED_SYMBOLS = new Set([
  '005930.KS', '000660.KS',
  'URA', 'CPER', 'ITA', 'XAR', 'DXYZ', 'VCX',
  'SATS',
]);

app.use('/api', (req, res, next) => {
  res.set('x-data-policy', 'live-only-no-static-market-fallback');
  if (req.path === '/issuer-data') {
    res.set('x-data-provider', 'SEC EDGAR (issuer-filed XBRL facts)');
  } else if (req.path === '/provenance') {
    res.set('x-data-provider', 'SEC EDGAR primary; Yahoo Finance reconciliation');
  } else {
    res.set('x-data-provider', 'Yahoo Finance (unofficial public endpoints)');
  }

  const requested = String(req.query.symbols || '').split(',')
    .map((symbol) => symbol.trim().toUpperCase()).filter(Boolean);
  const pathSymbol = String(req.path.split('/').pop() || '').toUpperCase();
  const excluded = requested.find((symbol) => EXCLUDED_SYMBOLS.has(symbol)) ||
    (EXCLUDED_SYMBOLS.has(pathSymbol) ? pathSymbol : null);
  if (excluded) {
    return res.status(410).json({ error: `${excluded} is excluded from the active public-company universe` });
  }
  const outside = requested.find((symbol) => !ACTIVE_SYMBOLS.has(symbol));
  if (outside) {
    return res.status(400).json({ error: `${outside} is outside the active public-company universe` });
  }
  next();
});

app.get('/api/issuer-data', async (req, res) => {
  const requested = String(req.query.symbols || '').split(',')
    .map((symbol) => symbol.trim().toUpperCase()).filter(Boolean);
  const symbols = requested.length ? [...new Set(requested)] : [...ACTIVE_SYMBOLS];
  try {
    const payload = await loadIssuerData(symbols);
    res.set('Cache-Control', 'public, max-age=300');
    return res.status(Object.keys(payload.issuers).length ? 200 : 503).json(payload);
  } catch (error) {
    return res.status(503).json({ error: `Issuer-filed data unavailable: ${error.message}` });
  }
});

app.get('/api/provenance', (req, res) => {
  res.json({
    reportedFundamentals: {
      provider: 'SEC EDGAR',
      access: 'Standardized XBRL facts from issuer filings',
      caveat: 'Only filed US-GAAP or IFRS facts are displayed. The mapped CIK and SEC entity name are exposed because SEC does not guarantee the scope or accuracy of its ticker-to-CIK association file. Missing issuer facts remain unavailable and are never filled from Yahoo.',
    },
    marketReconciliation: {
      provider: 'Yahoo Finance',
      access: 'Unofficial public endpoints via dashboard-core',
      caveat: 'Secondary market-data and estimate check only; never the source of record for reported results.',
    },
    universe: {
      file: 'universe.json',
      kind: 'Curated public-company coverage taxonomy only',
      asOf: universe.asOf,
      tickerCount: ACTIVE_SYMBOLS.size,
      exclusions: {
        unsupportedExchangeSymbols: ['005930.KS', '000660.KS'],
        fundsOrNonOperatingVehicles: ['URA', 'CPER', 'ITA', 'XAR', 'DXYZ', 'VCX'],
        noCurrentSecMapping: ['SATS'],
      },
    },
    fallbackPolicy: 'No static or Yahoo-derived value replaces a missing issuer-filed fundamental. No static market, conviction, forecast, options, insider, or news values are displayed.',
  });
});

app.use(coreApp);

module.exports = app;

if (require.main === module) {
  const PORT = process.env.PORT || 3000;
  app.listen(PORT, () => console.log(`AI Supply Chain Dashboard running on port ${PORT}`));
}
