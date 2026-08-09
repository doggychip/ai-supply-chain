# AI Supply Chain Dashboard

An evidence-first dashboard for a curated universe of 99 public companies across the AI infrastructure and physical-AI supply chain.

## Data policy

- **Primary reported fundamentals:** standardized US-GAAP or IFRS XBRL facts filed by each issuer and retrieved from the official SEC EDGAR APIs. Each displayed value includes the SEC entity, CIK, accounting concept, unit, period, filing date, form, and direct filing link.
- **Secondary reconciliation:** Yahoo Finance public endpoints via `dashboard-core`. Yahoo is used for current market context and same-period reconciliation; it never replaces a missing issuer-filed fundamental.
- **Fail closed:** missing, stale, unsupported, or incomparable data remains unavailable. The application does not ship static prices, valuation tables, earnings dates, forecasts, conviction scores, insider transactions, options simulations, or news claims.
- **Taxonomy:** `public/universe.json` contains company names and supply-chain classifications only. It is curated metadata, not an issuer fact or investment assessment.

SEC notes that its ticker-to-CIK association file is provided for convenience and does not guarantee accuracy or scope. The dashboard therefore exposes the mapped SEC entity name and CIK for verification.

## Pages

- Main: issuer-filed revenue, net income, diluted EPS, filing evidence, and Yahoo reconciliation.
- Correlation, technicals, market conditions, performance, and scenario calculator: calculated at runtime from current Yahoo quote/history responses and shown only when freshness and minimum-observation checks pass.
- Options: current nearest-expiration activity from Yahoo, with no direction or unusual-flow inference.
- Insider and news: intentionally unavailable until filing-level or article-level sources satisfying the stated acceptance criteria are implemented.

## Run and test

```bash
npm install
npm test
npm start
```

The server exposes `/api/provenance` and response headers (`x-data-policy`, `x-data-provider`) so clients and production checks can verify the source hierarchy programmatically.

For reliable SEC access in deployment, set `SEC_USER_AGENT` to a descriptive application identity with a monitored contact address, following SEC fair-access guidance.
