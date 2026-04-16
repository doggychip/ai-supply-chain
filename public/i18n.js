/* ========================================
   AI Supply Chain Dashboard — i18n System
   ======================================== */
// Use safeStorage if available (from page's own shim), otherwise use own store
var i18nStorage = (typeof safeStorage !== 'undefined') ? safeStorage : {
  _s: {},
  getItem: function(k) { return this._s[k] || null; },
  setItem: function(k, v) { this._s[k] = v; },

  // ── Cross-Dashboard Nav ──
  "AI Hardware":            { zh: "AI硬件" },
  "Software Stack":         { zh: "软件生态" },
  "Semi Equipment":         { zh: "半导体设备" },
  "News Feed":              { zh: "新闻动态" },
};

var I18N_LANG = i18nStorage.getItem('lang') || 'en';

var I18N = {
  // ── Tab Bar ──
  "Main Dashboard":       { zh: "主控面板" },
  "Correlation":          { zh: "相关性分析" },
  "Technicals":           { zh: "技术分析" },
  "Insider Activity":     { zh: "内部交易" },
  "Options Flow":         { zh: "期权动向" },
  "Sentiment":            { zh: "市场情绪" },
  "Leaderboard":          { zh: "排行榜" },
  "Stress Test":          { zh: "压力测试" },

  // ── Page Titles ──
  "AI Infrastructure — Complete Value Chain Research": { zh: "AI基础设施 — 完整价值链研究" },
  "Performance Leaderboard":        { zh: "绩效排行榜" },
  "Scenario / Stress Test":         { zh: "情景 / 压力测试" },
  "Market Sentiment Dashboard":     { zh: "市场情绪面板" },
  "Options Flow & Unusual Activity":{ zh: "期权动向 & 异常活动" },
  "Options Flow &amp; Unusual Activity":{ zh: "期权动向 & 异常活动" },
  "Insider & Institutional Activity":{ zh: "内部 & 机构交易活动" },
  "Insider &amp; Institutional Activity":{ zh: "内部 & 机构交易活动" },

  // ── Layer Names ──
  "GPU / Accelerators":         { zh: "GPU / 加速器" },
  "GPU/Accelerators":           { zh: "GPU / 加速器" },
  "Custom ASIC + Connectivity": { zh: "定制ASIC + 连接" },
  "Custom ASIC":                { zh: "定制ASIC" },
  "Foundry":                    { zh: "代工厂" },
  "Foundry + Packaging":        { zh: "代工厂 + 封装" },
  "Semi Equipment":             { zh: "半导体设备" },
  "News Feed":              { zh: "新闻动态" },
  "Memory (HBM)":               { zh: "内存 (HBM)" },
  "Memory/HBM":                 { zh: "内存 / HBM" },
  "Memory / HBM":               { zh: "内存 / HBM" },
  "Networking / Optics":        { zh: "网络 / 光学" },
  "Networking":                 { zh: "网络" },
  "Server OEMs":                { zh: "服务器OEM" },
  "Server OEM":                 { zh: "服务器OEM" },
  "Power & Cooling":            { zh: "电力 & 散热" },
  "Energy / Nuclear":           { zh: "能源 / 核能" },
  "Energy/Nuclear":             { zh: "能源 / 核能" },
  "Data Center REITs":          { zh: "数据中心REITs" },
  "Pivot Plays":                { zh: "转型概念" },
  "Pivot Plays (IREN/CIFR/NBIS)":{ zh: "转型概念 (IREN/CIFR/NBIS)" },
  "Neoclouds":                  { zh: "新型云服务" },
  "Hyperscalers":               { zh: "超大规模云" },

  // ── Index.html Section Buttons ──
  "Macro Dashboard":            { zh: "宏观面板" },
  "Value Chain Map":            { zh: "价值链图" },
  "Bottleneck Radar":           { zh: "瓶颈雷达" },
  "Master Watchlist":           { zh: "主观察列表" },
  "Conviction List":            { zh: "信心股票清单" },
  "Catalysts 2026–28":          { zh: "催化剂 2026–28" },
  "Earnings Calendar":          { zh: "财报日历" },

  // ── Common Table Headers ──
  "Ticker":         { zh: "代码" },
  "Company":        { zh: "公司" },
  "Name":           { zh: "名称" },
  "Layer":          { zh: "板块" },
  "Price":          { zh: "价格" },
  "Change %":       { zh: "涨跌幅 %" },
  "Chg %":          { zh: "涨跌%" },
  "Market Cap":     { zh: "市值" },
  "Mkt Cap":        { zh: "市值" },
  "Volume":         { zh: "成交量" },
  "Avg Volume":     { zh: "平均成交量" },
  "P/E":            { zh: "市盈率" },
  "P/S":            { zh: "市销率" },
  "EV/EBITDA":      { zh: "EV/EBITDA" },
  "D/E":            { zh: "负债/股东权益" },
  "ROE %":          { zh: "ROE %" },
  "Gross Margin %": { zh: "毛利率 %" },
  "Op Margin %":    { zh: "营业利润率 %" },
  "Net Margin %":   { zh: "净利率 %" },
  "FCF Margin %":   { zh: "自由现金流利润率 %" },
  "Key Metric":     { zh: "关键指标" },
  "Weight %":       { zh: "权重 %" },
  "$ Amount":       { zh: "金额 ($)" },
  "Status":         { zh: "状态" },
  "Thesis":         { zh: "投资论点" },
  "Signal":         { zh: "信号" },
  "Rank":           { zh: "排名" },
  "Severity":       { zh: "严重程度" },
  "Risk Level":     { zh: "风险级别" },

  // ── Sortable header suffixes ──
  "Ticker ▲▼":      { zh: "代码 ▲▼" },
  "Layer ▲▼":       { zh: "板块 ▲▼" },
  "P/E ▲▼":         { zh: "市盈率 ▲▼" },
  "P/S ▲▼":         { zh: "市销率 ▲▼" },
  "EV/EBITDA ▲▼":   { zh: "EV/EBITDA ▲▼" },
  "D/E ▲▼":         { zh: "负债率 ▲▼" },
  "ROE % ▲▼":       { zh: "ROE % ▲▼" },
  "Gross Margin % ▲▼":  { zh: "毛利率 % ▲▼" },
  "Op Margin % ▲▼":     { zh: "营业利润率 % ▲▼" },
  "Net Margin % ▲▼":    { zh: "净利率 % ▲▼" },
  "FCF Margin % ▲▼":    { zh: "自由现金流利润率 % ▲▼" },

  // ── Technicals ──
  "SMA-20":         { zh: "20日均线" },
  "SMA-50":         { zh: "50日均线" },
  "RSI-14":         { zh: "RSI-14" },
  "MACD Signal":    { zh: "MACD 信号" },
  "vs NVDA (rel)":  { zh: "相对NVDA" },

  // ── Insider ──
  "Net Insider Activity by Ticker":         { zh: "各股内部交易净额" },
  "Buy vs Sell Distribution (by Value)":    { zh: "买入 vs 卖出分布（按金额）" },
  "Activity Feed":                          { zh: "交易动态" },
  "Market Context — Insider-Active Tickers":{ zh: "市场概况 — 内部交易活跃个股" },
  "Net Value":          { zh: "净值" },
  "# Transactions":     { zh: "交易次数" },

  // ── Options ──
  "Market Tilt":                    { zh: "市场倾向" },
  "Options Activity Scanner":      { zh: "期权活动扫描" },
  "Options Sentiment Heat Map":    { zh: "期权情绪热力图" },
  "Volume vs Average Ratio":       { zh: "成交量 / 均量比" },
  "Simulated Large Block Trades":  { zh: "模拟大宗交易" },
  "Vol / Avg":          { zh: "量/均量" },
  "Activity":           { zh: "活跃度" },
  "Implied Sentiment":  { zh: "隐含情绪" },
  "Sim P/C Ratio":      { zh: "模拟P/C比" },

  // ── Sentiment ──
  "AI Supply Chain Fear & Greed":           { zh: "AI供应链恐惧与贪婪指数" },
  "AI Supply Chain Fear &amp; Greed":       { zh: "AI供应链恐惧与贪婪指数" },
  "Overall Market Sentiment":               { zh: "整体市场情绪" },
  "Top 5 Most Bullish":                     { zh: "最看涨前5" },
  "Top 5 Most Bearish":                     { zh: "最看跌前5" },
  "Sentiment Heatmap — All 36 Tickers":     { zh: "情绪热力图 — 全部36只股票" },
  "Sector Sentiment Breakdown":             { zh: "板块情绪分析" },
  "Sector Sentiment Comparison":            { zh: "板块情绪对比" },
  "AI Narrative Tracker":                   { zh: "AI叙事追踪器" },
  "Sentiment Score Card — All Tickers":     { zh: "情绪评分卡 — 全部股票" },
  "Sentiment":          { zh: "情绪" },
  "Composite Score":    { zh: "综合评分" },
  "Vol Ratio":          { zh: "量比" },
  "52W Position":       { zh: "52周位置" },

  // ── Leaderboard ──
  "Top 5 Performers":   { zh: "涨幅前5" },
  "Bottom 5 Performers":{ zh: "跌幅前5" },
  "All Tickers — Ranked by Return":     { zh: "全部股票 — 按收益排名" },
  "Returns by Ticker":                  { zh: "各股收益率" },
  "Sector Performance (Avg Return)":    { zh: "板块表现（平均收益）" },
  "Market Cap Treemap":                 { zh: "市值树图" },

  // ── Stress Test ──
  "Select Scenario":                    { zh: "选择情景" },
  "Impact Waterfall by Layer":          { zh: "板块影响瀑布图" },
  "Impact Distribution":               { zh: "影响分布" },
  "Supply Chain Cascade":              { zh: "供应链级联效应" },
  "Portfolio Impact Calculator":        { zh: "投资组合影响计算器" },
  "Impact Table — All Tickers":         { zh: "影响表 — 全部股票" },
  "Cross-Scenario Risk Ranking":        { zh: "跨情景风险排名" },
  "Custom Shock by Sector Layer (%)":   { zh: "自定义板块冲击 (%)" },
  "Current":            { zh: "当前价" },
  "$ Change":           { zh: "$ 变动" },
  "% Change":           { zh: "% 变动" },
  "Avg Impact":         { zh: "平均影响" },

  // ── Scenario names ──
  "Tariff War":         { zh: "贸易战" },
  "AI Winter":          { zh: "AI寒冬" },
  "Rate Shock":         { zh: "利率冲击" },
  "HBM Glut":           { zh: "HBM供过于求" },
  "Nuclear Setback":    { zh: "核能挫折" },
  "Scenario":           { zh: "情景" },

  // ── Correlation ──
  "30-Day":             { zh: "30天" },
  "90-Day":             { zh: "90天" },
  "By Layer":           { zh: "按板块" },
  "By Avg Corr":        { zh: "按平均相关性" },

  // ── Common UI words ──
  "Toggle Theme":       { zh: "切换主题" },
  "◑ Theme":            { zh: "◑ 主题" },
  "Bullish":            { zh: "看涨" },
  "Bearish":            { zh: "看跌" },
  "Neutral":            { zh: "中性" },
  "Strong Buy":         { zh: "强烈买入" },
  "Buy":                { zh: "买入" },
  "Sell":               { zh: "卖出" },
  "Hold":               { zh: "持有" },
  "Overbought":         { zh: "超买" },
  "Oversold":           { zh: "超卖" },
  "High":               { zh: "高" },
  "Medium":             { zh: "中" },
  "Low":                { zh: "低" },
  "Upcoming":           { zh: "即将公布" },
  "Reported":           { zh: "已公布" },

  // ── Descriptions / Subtitles ──
  "Sized by market cap, colored by return for selected period": { zh: "面积按市值，颜色按所选期间收益率" },
  "Simplified flow showing how a shock propagates through the AI supply chain": { zh: "简化流程图展示冲击如何在AI供应链中传导" },
  "Enter share quantities to see simulated portfolio impact": { zh: "输入持仓股数查看模拟投资组合影响" },

  // ── Language toggle ──
  "EN":   { zh: "EN" },
  "中文": { zh: "中文" },

  // ── Index.html Sidebar Categories ──
  "Silicon Stack":      { zh: "芯片层" },
  "Infrastructure":     { zh: "基础设施" },
  "Cloud Layer":        { zh: "云服务层" },
  "Analysis":           { zh: "分析" },
  "Tools":              { zh: "工具" },
  "Overview":           { zh: "概览" },

  // ── Macro Dashboard Stat Cards ──
  "📊 Macro Dashboard":               { zh: "📊 宏观面板" },
  "🗺 Complete Value Chain Map":      { zh: "🗺 完整价值链图" },
  "🔴 Bottleneck Radar":              { zh: "🔴 瓶颈雷达" },
  "The numbers that anchor the entire thesis": { zh: "支撑整体投资论点的核心数据" },
  "14 layers from energy to cloud — click a ticker to open detailed analysis": { zh: "从能源到云端的14层 — 点击代码查看详细分析" },
  "Hyperscaler Capex 2026E":          { zh: "超大规模云资本支出 2026E" },
  "HYPERSCALER CAPEX 2026E":          { zh: "超大规模云资本支出 2026E" },
  "Global AI Infra Spend →2028":      { zh: "全球AI基建支出 →2028" },
  "GLOBAL AI INFRA SPEND →2028":      { zh: "全球AI基建支出 →2028" },
  "DC Power Load 2028E":              { zh: "数据中心电力负载 2028E" },
  "DC POWER LOAD 2028E":              { zh: "数据中心电力负载 2028E" },
  "WFE Market 2026E":                 { zh: "晶圆设备市场 2026E" },
  "WFE MARKET 2026E":                 { zh: "晶圆设备市场 2026E" },
  "HBM Market 2028E":                 { zh: "HBM市场 2028E" },
  "HBM MARKET 2028E":                 { zh: "HBM市场 2028E" },
  "CoWoS Supply/Demand Gap":          { zh: "CoWoS供需缺口" },
  "COWOS SUPPLY/DEMAND GAP":          { zh: "CoWoS供需缺口" },
  "NVIDIA FY26 Revenue":              { zh: "英伟达FY26营收" },
  "NVIDIA FY26 REVENUE":              { zh: "英伟达FY26营收" },
  "SMCI Export Indictment Impact":    { zh: "超微电脑出口起诉影响" },
  "SMCI EXPORT INDICTMENT IMPACT":    { zh: "超微电脑出口起诉影响" },

  // ── Chart / Card Titles ──
  "US Data Center Power Demand (TWh)": { zh: "美国数据中心电力需求 (TWh)" },
  "US DATA CENTER POWER DEMAND (TWH)": { zh: "美国数据中心电力需求 (TWH)" },
  "HBM Market Size ($B) — Supply vs Demand": { zh: "HBM市场规模 ($B) — 供给 vs 需求" },
  "HBM MARKET SIZE ($B) — SUPPLY VS DEMAND": { zh: "HBM市场规模 ($B) — 供给 vs 需求" },
  "Supply Tightness vs Demand (2026)": { zh: "供给紧张程度 vs 需求 (2026)" },
  "SUPPLY TIGHTNESS VS DEMAND (2026)": { zh: "供给紧张程度 vs 需求 (2026)" },
  "Constraint Map":                   { zh: "约束地图" },
  "GPU / Accelerator Revenue Ramp ($B)": { zh: "GPU / 加速器营收增长 ($B)" },
  "AVGO AI Revenue Quarterly ($B)":   { zh: "博通AI季度营收 ($B)" },
  "MRVL + ALAB + CRDO Revenue YoY Growth (%)": { zh: "MRVL + ALAB + CRDO 营收同比增长 (%)" },
  "TSMC & Foundry Metrics":           { zh: "台积电 & 代工厂指标" },
  "Semi Equipment — Latest Results & Thesis": { zh: "半导体设备 — 最新业绩 & 论点" },
  "HBM Market Share 2026E & Revenue Growth": { zh: "HBM 市场份额 2026E & 营收增长" },
  "CoreWeave Key Contract Breakdown": { zh: "CoreWeave 关键合约分析" },
  "2026E Capital Expenditure by Hyperscaler ($B)": { zh: "2026E 超大规模云资本支出 ($B)" },
  "2026 Catalysts":                   { zh: "2026 催化剂" },
  "2027–2028 Catalysts":              { zh: "2027–2028 催化剂" },

  // ── Bottleneck Radar items ──
  "HBM Memory":                       { zh: "HBM 内存" },
  "CoWoS Packaging":                  { zh: "CoWoS 封装" },
  "GPU Compute":                      { zh: "GPU 算力" },
  "Grid Power":                       { zh: "电网电力" },
  "Optics / EML":                     { zh: "光学 / EML" },
  "Power Delivery (VRT/ETN)":         { zh: "电力传输 (VRT/ETN)" },
  "Gas Turbines (GEV)":               { zh: "燃气轮机 (GEV)" },
  "Networking (Ethernet)":            { zh: "网络 (以太网)" },
  "Server OEM (post-SMCI)":           { zh: "服务器OEM (后SMCI时代)" },
  "DC REIT Capacity":                 { zh: "数据中心REIT容量" },

  // ── Layer Section Headers ──
  "🟣 Layer 1 — GPU / AI Accelerators":   { zh: "🟣 第1层 — GPU / AI加速器" },
  "🔵 Layer 2 — Custom ASIC + Connectivity": { zh: "🔵 第2层 — 定制ASIC + 连接" },
  "🔵 Layers 3 & 4 — Foundry + Semi Equipment": { zh: "🔵 第3&4层 — 代工厂 + 半导体设备" },
  "🟡 Layer 5 — Memory / HBM":            { zh: "🟡 第5层 — 内存 / HBM" },
  "🟠 Layer 6 — Networking / Optics":      { zh: "🟠 第6层 — 网络 / 光学" },
  "🟠 Layer 7 — Server OEMs":              { zh: "🟠 第7层 — 服务器OEM" },
  "🔴 Layer 8 — Power & Cooling":          { zh: "🔴 第8层 — 电力 & 散热" },
  "🔴 Layer 9 — Energy / Nuclear":         { zh: "🔴 第9层 — 能源 / 核能" },
  "🏢 Layer 10 — Data Center REITs":       { zh: "🏢 第10层 — 数据中心REITs" },
  "⛏ Pivot Plays":                        { zh: "⛏ 转型概念" },
  "☁ Neoclouds":                          { zh: "☁ 新型云服务" },
  "📋 Conviction List":                   { zh: "📋 信心股票清单" },
  "📅 Catalysts Timeline":                { zh: "📅 催化剂时间线" },
  "📅 Earnings Calendar":                 { zh: "📅 财报日历" },

  // ── Misc Labels ──
  "Capacity utilization as % of demand — higher = more constrained = more pricing power": { zh: "产能利用率占需求百分比 — 越高 = 越紧缺 = 定价权越强" },
  "Supply":              { zh: "\u4f9b\u7ed9" },
  "Demand":              { zh: "需求" },
  "Revenue":             { zh: "营收" },
  "Growth":              { zh: "增长" },
  "Margin":              { zh: "利润率" },
  "Capex":               { zh: "资本支出" },
  "YoY":                 { zh: "同比" },
  "QoQ":                 { zh: "环比" },
  "Market Share":        { zh: "市场份额" },
};

/* ── Company Name Translations ── */
var I18N_COMPANIES = {
  "NVIDIA Corporation": "英伟达",
  "Advanced Micro Devices, Inc.": "超威半导体 (AMD)",
  "Arm Holdings plc American Depositary Shares": "Arm 控股",
  "Arm Holdings plc": "Arm 控股",
  "Intel Corporation": "英特尔",
  "Broadcom Inc.": "博通",
  "Marvell Technology, Inc.": "美满电子",
  "Astera Labs, Inc. Common Stock": "Astera Labs",
  "Astera Labs, Inc.": "Astera Labs",
  "Credo Technology Group Holding Ltd": "Credo 科技",
  "Taiwan Semiconductor Manufacturing Company Limited": "台积电",
  "Taiwan Semiconductor Manufacturing": "台积电",
  "ASML Holding N.V.": "阿斯麦 (ASML)",
  "Applied Materials, Inc.": "应用材料",
  "Lam Research Corporation": "拉姆研究",
  "KLA Corporation": "科磊 (KLA)",
  "Teradyne, Inc.": "泰瑞达",
  "Advanced Energy Industries, Inc.": "先进能源工业",
  "Micron Technology, Inc.": "美光科技",
  "Sandisk Corporation": "闪迪",
  "SanDisk Corporation": "闪迪",
  "Arista Networks, Inc.": "Arista 网络",
  "Lumentum Holdings Inc.": "Lumentum 光电",
  "Amphenol Corporation": "安费诺",
  "Dell Technologies Inc.": "戴尔科技",
  "Super Micro Computer, Inc.": "超微电脑",
  "Hewlett Packard Enterprise Company": "慧与科技 (HPE)",
  "Vertiv Holdings Co": "维谛技术 (Vertiv)",
  "Eaton Corporation plc": "伊顿",
  "Eaton Corporation, PLC": "伊顿",
  "GE Vernova Inc.": "通用电气Vernova",
  "Constellation Energy Corporation": "星座能源",
  "Vistra Corp.": "维斯特拉能源",
  "Oklo Inc.": "Oklo 核能",
  "BWX Technologies, Inc.": "BWX 技术",
  "Digital Realty Trust, Inc.": "数字不动产信托",
  "Equinix, Inc.": "Equinix 数据中心",
  "Iron Mountain Incorporated": "铁山",
  "IREN Limited": "IREN (算力转型)",
  "Cipher Mining Inc.": "Cipher 挖矿",
  "Nebius Group N.V.": "Nebius 集团",
  "CoreWeave, Inc.": "CoreWeave 云",
  "CoreWeave, Inc. Class A Common Stock": "CoreWeave 云",
};

/* ── Translation Function ── */
function t(key) {
  if (I18N_LANG === 'en') return key;
  var entry = I18N[key];
  if (entry && entry.zh) return entry.zh;
  // Try normalized lookup (replace various dash types with standard em-dash)
  var normalized = key.replace(/[\u2012\u2013\u2014\u2015\u2212—–-]+/g, '\u2014');
  if (normalized !== key) {
    entry = I18N[normalized];
    if (entry && entry.zh) return entry.zh;
  }
  return key;
}

function tCompany(name) {
  if (I18N_LANG === 'en') return name;
  return I18N_COMPANIES[name] || name;
}

/* ── Apply translations to static DOM elements ── */
function applyI18n() {
  // Translate tab links
  document.querySelectorAll('.tab-link').forEach(function(el) {
    var orig = el.getAttribute('data-i18n') || el.textContent.trim();
    if (!el.getAttribute('data-i18n')) el.setAttribute('data-i18n', orig);
    el.textContent = t(orig);
  });

  // Translate h1, h2, h3
  document.querySelectorAll('h1, h2, h3').forEach(function(el) {
    // Skip if it contains child elements that aren't just text
    if (el.querySelector('button, input, select')) return;
    var orig = el.getAttribute('data-i18n') || el.innerHTML.trim();
    if (!el.getAttribute('data-i18n')) el.setAttribute('data-i18n', orig);
    el.innerHTML = t(orig);
  });

  // Translate buttons (but not period buttons like 1D, 1W etc., and not sb-item which are handled separately)
  document.querySelectorAll('button').forEach(function(el) {
    if (el.classList.contains('sb-item')) return;
    var txt = el.textContent.trim();
    if (/^[0-9]/.test(txt) || txt === '×' || txt === '&times;' || txt.length > 60) return;
    var orig = el.getAttribute('data-i18n') || txt;
    if (!el.getAttribute('data-i18n')) el.setAttribute('data-i18n', orig);
    var translated = t(orig);
    if (translated !== orig) el.textContent = translated;
  });

  // Translate th elements
  document.querySelectorAll('th').forEach(function(el) {
    var orig = el.getAttribute('data-i18n') || el.textContent.trim();
    if (!el.getAttribute('data-i18n')) el.setAttribute('data-i18n', orig);
    var translated = t(orig);
    if (translated !== orig) el.textContent = translated;
  });

  // Translate p subtitles
  document.querySelectorAll('p').forEach(function(el) {
    var orig = el.getAttribute('data-i18n') || el.textContent.trim();
    if (I18N[orig]) {
      if (!el.getAttribute('data-i18n')) el.setAttribute('data-i18n', orig);
      el.textContent = t(orig);
    }
  });

  // Translate nav section buttons on index.html
  document.querySelectorAll('.nav-btn, .section-btn, [data-section]').forEach(function(el) {
    var orig = el.getAttribute('data-i18n') || el.textContent.trim();
    if (!el.getAttribute('data-i18n')) el.setAttribute('data-i18n', orig);
    el.textContent = t(orig);
  });

  // Translate sidebar items (sb-item buttons) — preserve inner <span> dot
  document.querySelectorAll('.sb-item').forEach(function(el) {
    // The button has <span class="dot">...</span> + text node
    var textNodes = [];
    el.childNodes.forEach(function(n) {
      if (n.nodeType === 3 && n.textContent.trim()) textNodes.push(n);
    });
    if (textNodes.length > 0) {
      var orig = el.getAttribute('data-i18n') || textNodes[0].textContent.trim();
      if (!el.getAttribute('data-i18n')) el.setAttribute('data-i18n', orig);
      textNodes[0].textContent = t(orig);
    }
  });

  // Translate sidebar section titles
  document.querySelectorAll('.sb-section-title').forEach(function(el) {
    var orig = el.getAttribute('data-i18n') || el.textContent.trim();
    if (!el.getAttribute('data-i18n')) el.setAttribute('data-i18n', orig);
    el.textContent = t(orig);
  });

  // Translate card-title, sbar-label, kpi-label, section-header, stat-label elements
  document.querySelectorAll('.card-title, .sbar-label, .sec-title, .section-title, .section-header, .stat-title, .stat-label, .mr-label, .sc-metric-label, .rsk-title, .sidebar-group-title, .sidebar-category, .kpi-label, .section-desc').forEach(function(el) {
    var orig = el.getAttribute('data-i18n') || el.textContent.trim();
    if (!el.getAttribute('data-i18n')) el.setAttribute('data-i18n', orig);
    el.textContent = t(orig);
  });

  // Translate descriptions and subtitles with broad matching
  document.querySelectorAll('.sec-sub, .section-sub, .card-sub, .subtitle').forEach(function(el) {
    var orig = el.getAttribute('data-i18n') || el.textContent.trim();
    if (I18N[orig]) {
      if (!el.getAttribute('data-i18n')) el.setAttribute('data-i18n', orig);
      el.textContent = t(orig);
    }
  });

  // Update lang toggle button text
  var langBtn = document.getElementById('langToggle');
  if (langBtn) {
    langBtn.textContent = I18N_LANG === 'en' ? '中文' : 'EN';
  }
}

/* ── Translate dynamic content (company names, layer names in table cells) ── */
function applyI18nDynamic() {
  // Translate company names in table cells
  document.querySelectorAll('td').forEach(function(el) {
    var txt = el.textContent.trim();
    if (I18N_COMPANIES[txt]) {
      el.textContent = I18N_LANG === 'en' ? txt : I18N_COMPANIES[txt];
    }
    // Check for layer names in cells
    if (I18N[txt] && I18N[txt].zh) {
      el.textContent = t(txt);
    }
  });

  // Translate layer names in any element with class containing 'layer', 'sector', 'category'
  document.querySelectorAll('[class*="layer"], [class*="sector"], [class*="category"], .hl-name, .sector-name').forEach(function(el) {
    var txt = el.textContent.trim();
    if (I18N_COMPANIES[txt]) {
      el.textContent = I18N_LANG === 'en' ? txt : I18N_COMPANIES[txt];
    }
    if (I18N[txt] && I18N[txt].zh) {
      el.textContent = t(txt);
    }
  });

  // Translate labels in cards, divs with financial text
  document.querySelectorAll('.card-label, .metric-label, .stat-label, dt, label').forEach(function(el) {
    var txt = el.textContent.trim();
    if (I18N[txt] && I18N[txt].zh) {
      el.textContent = t(txt);
    }
  });

  // Translate option/select elements
  document.querySelectorAll('option').forEach(function(el) {
    var orig = el.getAttribute('data-i18n') || el.textContent.trim();
    if (I18N[orig] && I18N[orig].zh) {
      if (!el.getAttribute('data-i18n')) el.setAttribute('data-i18n', orig);
      el.textContent = t(orig);
    }
  });
}

/* ── Toggle Language ── */
function toggleLang() {
  I18N_LANG = I18N_LANG === 'en' ? 'zh' : 'en';
  i18nStorage.setItem('lang', I18N_LANG);
  applyI18n();
  // Re-render dynamic content if renderAll exists
  if (typeof renderAll === 'function') {
    try { renderAll(); } catch(e) {}
  }
  if (typeof renderTable === 'function' && typeof renderAll !== 'function') {
    try { renderTable(); } catch(e) {}
  }
  // Apply dynamic translations after re-render
  applyI18nDynamic();
}

/* ── Inject language toggle button into tab bar ── */
function injectLangToggle() {
  var nav = document.querySelector('.tab-bar');
  if (!nav) return;
  // Check if already exists
  if (document.getElementById('langToggle')) return;
  var btn = document.createElement('button');
  btn.id = 'langToggle';
  btn.className = 'lang-toggle-btn';
  btn.textContent = I18N_LANG === 'en' ? '中文' : 'EN';
  btn.onclick = toggleLang;
  btn.style.cssText = 'margin-left:auto;padding:4px 14px;border-radius:6px;border:1px solid rgba(255,255,255,0.15);background:rgba(255,255,255,0.06);color:inherit;font-size:13px;font-weight:600;cursor:pointer;letter-spacing:0.5px;transition:all 0.2s;white-space:nowrap;';
  btn.onmouseenter = function() { btn.style.background = 'rgba(99,102,241,0.25)'; };
  btn.onmouseleave = function() { btn.style.background = 'rgba(255,255,255,0.06)'; };
  nav.appendChild(btn);
}

/* ── Auto-init on DOM ready ── */
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', function() {
    injectLangToggle();
    applyI18n();
    applyI18nDynamic();
  });
} else {
  injectLangToggle();
  applyI18n();
  applyI18nDynamic();
}
