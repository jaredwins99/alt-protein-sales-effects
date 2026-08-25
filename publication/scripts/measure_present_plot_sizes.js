// Measure each present/ plot HTML's natural height at a fixed wide width,
// writing publication/scripts/present_plot_sizes.json for make_present_grids.py.
//
// Needed because the grid renders each iframe WIDE and CSS-scales it down.
// Rendering at tile width instead makes plotly reflow to ~300px, which collides
// the facet strip labels and pushes the x-axis out of frame.
//
// Usage (requires playwright-core + a chromium build):
//   CHROME=<chrome-headless-shell> node publication/scripts/measure_present_plot_sizes.js \
//     present/total_adjusted/*/*.html
// Re-run after any present/ rebuild that changes plot heights.
const { chromium } = require('/tmp/pw/node_modules/playwright-core');
const fs = require('fs');
(async () => {
  const W = 1400;
  const files = process.argv.slice(2);
  const b = await chromium.launch({ executablePath: process.env.CHROME });
  const p = await b.newPage({ viewport: { width: W, height: 1000 } });
  const out = {};
  for (const f of files) {
    await p.goto('file://' + f, { waitUntil: 'networkidle', timeout: 120000 });
    await p.waitForTimeout(1200);
    const h = await p.evaluate(() => {
      const el = document.querySelector('.plotly') || document.querySelector('.html-widget') || document.body;
      return Math.ceil(Math.max(el.getBoundingClientRect().height, document.body.scrollHeight));
    });
    const key = f.split('/').slice(-2).join('/');
    out[key] = { w: W, h };
  }
  fs.writeFileSync('/home/godli/testing/publication/scripts/present_plot_sizes.json', JSON.stringify(out, null, 1));
  console.log('measured ' + Object.keys(out).length + ' plots at width ' + W);
  await b.close();
})();
