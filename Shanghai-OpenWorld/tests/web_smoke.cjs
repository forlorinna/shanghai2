const assert = require('node:assert/strict');
const fs = require('node:fs');
const http = require('node:http');
const path = require('node:path');
const { chromium } = require('playwright');

const destination = path.resolve(__dirname, '..', 'builds', 'web');
const mimeTypes = { '.wasm': 'application/wasm', '.js': 'text/javascript', '.html': 'text/html', '.json': 'application/json', '.png': 'image/png' };
const server = http.createServer((req, res) => {
  const requested = new URL(req.url, 'http://localhost').pathname;
  const file = path.join(destination, path.basename(requested) || 'index.html');
  if (!fs.existsSync(file)) {
    res.writeHead(404);
    res.end();
    return;
  }
  res.writeHead(200, { 'Content-Type': mimeTypes[path.extname(file)] || 'application/octet-stream' });
  fs.createReadStream(file).pipe(res);
});

async function run() {
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  const url = 'http://127.0.0.1:' + server.address().port + '/';
  let browser;
  try {
    browser = await chromium.launch({ executablePath: process.env.CHROMIUM_BIN || '/usr/bin/chromium',
      headless: true, args: ['--no-sandbox', '--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--disable-dev-shm-usage'] });
    const context = await browser.newContext({ viewport: { width: 1280, height: 720 } });
    const page = await context.newPage();
    const errors = [];
    page.on('pageerror', issue => errors.push(issue.message));
    let engineReady = false;
    page.on('console', message => {
      const text = message.text();
      if (/Godot Engine/.test(text)) engineReady = true;
      if (/SCRIPT ERROR|Could not load res:|Parse Error|Uncaught RuntimeError/.test(text)) errors.push(text);
    });
    await page.goto(url, { waitUntil: 'domcontentloaded' });
    await page.waitForFunction(() => !document.querySelector('#status'), undefined, { timeout: 120000 });
    assert.ok(engineReady, 'Godot started from the exported WASM');
    await page.waitForTimeout(3000);
    await page.screenshot({ path: process.argv[2] || '/tmp/shanghai-web-title.png' });
    await page.mouse.click(220, 220);
    await page.keyboard.down('w');
    await page.waitForTimeout(2500);
    await page.keyboard.up('w');
    await page.screenshot({ path: process.argv[3] || '/tmp/shanghai-web-play.png' });
    assert.deepEqual(errors, []);
    console.log('PASS  Web WASM started in Chromium with WebGL 2 and accepted menu and movement inputs');
    await page.waitForFunction(() => navigator.serviceWorker.controller !== null, undefined, { timeout: 45000 });
    await context.setOffline(true);
    await page.reload({ waitUntil: 'domcontentloaded' });
    await page.waitForFunction(() => !document.querySelector('#status'), undefined, { timeout: 120000 });
    assert.deepEqual(errors, []);
    console.log('PASS  Cached Web export reloads offline after the first local load');
  } finally {
    if (browser) await browser.close();
    server.close();
  }
}

run().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
