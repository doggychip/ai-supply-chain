// Thin wrapper around dashboard-core. All Yahoo proxy / static / cache
// logic lives in dashboard-core; this file just configures the dashboard.

const path = require('path');
const { createDashboardServer } = require('dashboard-core');

const app = createDashboardServer({
  publicDir: path.join(__dirname, 'public'),
  // TICKER_DATA currently lives inline in public/index.html. A future PR can
  // extract it to public/ai_data.json (matching sw_data.json / semi_data.json),
  // and then point tickerData at that file to populate CANONICAL_TICKERS.
  tickerData: null,
  newsDataPath: path.join(__dirname, 'news_data.json'),
  dashboardName: 'AI Supply Chain',
});

// Export the app so smoke tests / other callers can mount it without binding.
module.exports = app;

// Only bind when run directly via `node server.js` (not when require()'d).
if (require.main === module) {
  const PORT = process.env.PORT || 3000;
  app.listen(PORT, () => console.log(`AI Supply Chain Dashboard running on port ${PORT}`));
}
