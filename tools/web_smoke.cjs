/* Optional rendered browser checks. Requires Playwright and a served Web export.
 * SCREWCRAFT_PLAYWRIGHT can point to a locally installed Playwright package.
 * This exercises actual canvas pointer/touch input; model assertions live in Godot tests.
 */
const { chromium } = require(process.env.SCREWCRAFT_PLAYWRIGHT || '/workspace/.tools/browser/node_modules/playwright');
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const assert = require('node:assert/strict');
const output = path.resolve('builds/reports');
const url = process.env.SCREWCRAFT_WEB_URL || 'http://127.0.0.1:8765';
const digest = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
const pause = ms => new Promise(resolve => setTimeout(resolve, ms));

(async () => {
  fs.mkdirSync(output, { recursive: true });
  const browser = await chromium.launch({
    executablePath: process.env.CHROMIUM_BIN || '/usr/bin/chromium', headless: true,
    args: ['--no-sandbox', '--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'],
  });
  const errors = [];
  const desktop = await browser.newContext({ viewport: { width: 720, height: 1280 } });
  const page = await desktop.newPage();
  page.on('pageerror', e => errors.push(e.message));
  page.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });
  await page.goto(url);
  await pause(3500);
  const snapshot = name => page.screenshot({ path: path.join(output, name + '.png') });
  const boardHash = async () => digest(await page.screenshot({ clip: { x: 40, y: 444, width: 640, height: 600 } }));
  const click = async (x, y) => { await page.mouse.click(x, y); await pause(600); };
  await snapshot('game-initial');
  const initial = await boardHash();
  await click(260, 649);
  const moved = await boardHash();
  assert.notEqual(moved, initial, 'A real board click must remove a visible screw');
  await click(140, 1154);
  assert.equal(await boardHash(), initial, 'Undo must visually restore the whole board');
  await click(260, 649);
  await pause(600);
  await page.reload();
  await pause(3500);
  assert.equal(await boardHash(), moved, 'A fresh Web runtime must restore the saved move');
  for (const [x, y] of [[360,649], [460,649], [260,839], [360,839], [460,839]]) await click(x,y);
  await snapshot('victory');
  const result = await page.screenshot({ clip: { x: 90, y: 240, width: 540, height: 790 } });
  await click(360, 980); // Collection.
  await snapshot('collection');
  await click(120, 62);  // Workshop.
  await snapshot('workshop');
  await click(360, 855); // Continue must restore terminal controls.
  assert.equal(digest(await page.screenshot({ clip: { x: 90, y: 240, width: 540, height: 790 } })), digest(result), 'Returning to a won attempt preserves its result controls');
  await click(360, 892); // Next.
  await snapshot('level-02');
  await click(68, 63);
  await click(360, 945);
  await click(420, 1134); // Last catalogue page.
  await snapshot('level-shelf-1000');
  await click(624, 878);
  await snapshot('level-1000');
  await click(579, 1154);
  await snapshot('blueprint-1000');
  await click(360, 1154);
  await click(652, 63);
  await snapshot('settings');
  await desktop.close();

  const phone = await browser.newContext({ viewport: { width: 360, height: 800 }, hasTouch: true, isMobile: true });
  const touchPage = await phone.newPage();
  touchPage.on('pageerror', e => errors.push(e.message));
  await touchPage.goto(url);
  await pause(3500);
  const phoneBoard = async () => digest(await touchPage.screenshot({ clip: { x: 20, y: 302, width: 320, height: 300 } }));
  const untouched = await phoneBoard();
  await touchPage.touchscreen.tap(130, 404.5); // 720x1280 canvas centered at y80.
  await pause(650);
  assert.notEqual(await phoneBoard(), untouched, 'Real touch input must remove one screw');
  await touchPage.touchscreen.tap(70, 657);
  await pause(650);
  assert.equal(await phoneBoard(), untouched, 'Touch must operate the native Undo button');
  await touchPage.screenshot({ path: path.join(output, 'phone-360x800.png') });
  await phone.close();
  await browser.close();
  assert.deepEqual(errors, [], 'No Web engine or browser errors');
  const report = { status: 'PASS', checks: 7, platform: 'Chromium software WebGL', actual_touch_events: true,
    viewport_sizes: ['720x1280', '360x800'], errors,
    scope: 'Rendered clicks/touch, undo, browser reload persistence, result navigation and screenshots. Not a physical phone test.' };
  fs.writeFileSync(path.join(output, 'web-smoke.json'), JSON.stringify(report, null, 2) + '\n');
  console.log(JSON.stringify(report));
})().catch(error => { console.error(error); process.exit(1); });
