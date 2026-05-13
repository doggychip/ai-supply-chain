// Pre-merge syntax + sanity checks for ai-supply-chain.
//
// Catches the failure mode of every silent-failure bug we shipped to main
// before this script existed:
//   - PR #8  (CIFR comma) — inline <script> block failed to parse, killing
//             const TICKER_DATA = {…} silently
//   - PR #9  (i18n.js)    — translations pasted inside injectLangToggle()
//             function body, SyntaxError at the colon
//
// node --check on standalone JS catches (2). new vm.Script() on each inline
// <script> block in our HTML catches (1). A runtime smoke (vm.runInNewContext
// on the TICKER_DATA literal) catches the case where the block parses but
// the const declaration is unreachable (e.g., earlier code throws), which
// the static check alone would miss.
//
// Exit code 1 if any check fails, so CI fails the PR.

const fs = require('fs');
const vm = require('vm');

let failed = 0;
const results = [];

function check(name, fn) {
  try {
    const detail = fn();
    results.push(`PASS  ${name}${detail ? ` — ${detail}` : ''}`);
  } catch (e) {
    results.push(`FAIL  ${name}\n      → ${e.message}`);
    failed++;
  }
}

// 1) Standalone JS files (currently just public/i18n.js — add more if we
//    introduce more standalone scripts later)
const standaloneJs = ['public/i18n.js'].filter(fs.existsSync);
for (const file of standaloneJs) {
  check(`syntax: ${file}`, () => {
    new vm.Script(fs.readFileSync(file, 'utf8'), { filename: file });
  });
}

// 2) Every inline <script> block in every HTML file under public/.
//    Skips external <script src="…"> tags (those are covered by step 1
//    when they reference local files).
const htmlFiles = fs.readdirSync('public')
  .filter(f => f.endsWith('.html'))
  .map(f => `public/${f}`);

const inlineScriptRe = /<script(?![^>]*\bsrc=)[^>]*>([\s\S]*?)<\/script>/gi;
for (const htmlFile of htmlFiles) {
  const src = fs.readFileSync(htmlFile, 'utf8');
  let m;
  let idx = 0;
  while ((m = inlineScriptRe.exec(src)) !== null) {
    idx++;
    const body = m[1];
    // Skip trivial / empty blocks (e.g., one-liner Chart.js fallback)
    if (body.trim().length < 20) continue;
    const lineNumber = src.slice(0, m.index).split('\n').length;
    const label = `syntax: ${htmlFile} inline <script> #${idx} (line ${lineNumber})`;
    check(label, () => {
      new vm.Script(body, { filename: `${htmlFile}#script${idx}` });
    });
  }
}

// 3) Runtime smoke: TICKER_DATA must parse AND produce a sensible ticker
//    count. Catches the class of failures where the syntax is valid but
//    the const declaration never executes (e.g., earlier line throws),
//    leaving TICKER_DATA undefined for every downstream consumer.
check('runtime: TICKER_DATA parses and yields tickers', () => {
  const html = fs.readFileSync('public/index.html', 'utf8');
  const m = html.match(/const TICKER_DATA = \{[\s\S]*?\n\};/);
  if (!m) throw new Error('TICKER_DATA literal not found in public/index.html');
  const wrapped = '(function(){' + m[0] + ';return Object.keys(TICKER_DATA).length;})()';
  const count = vm.runInNewContext(wrapped);
  if (count < 50) throw new Error(`expected at least 50 tickers, got ${count}`);
  return `${count} tickers`;
});

console.log(results.join('\n'));
if (failed) {
  console.error(`\n${failed} check(s) failed.`);
  process.exit(1);
}
console.log(`\nAll checks passed.`);
