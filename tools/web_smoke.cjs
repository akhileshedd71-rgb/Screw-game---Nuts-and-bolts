/* Actual Godot WebGL pointer/touch regression, using native App button geometry.
 * Run tools/capture_redesign.gd at 720x1280 first, then serve builds/web on :8765.
 * SCREWCRAFT_PLAYWRIGHT may select a local Playwright installation.
 */
const { chromium } = require(process.env.SCREWCRAFT_PLAYWRIGHT || '/workspace/.tools/browser/node_modules/playwright');
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const assert = require('node:assert/strict');
const output = path.resolve('builds/reports');
const url = process.env.SCREWCRAFT_WEB_URL || 'http://127.0.0.1:8765';
const geometry = JSON.parse(fs.readFileSync(path.join(output, 'redesign/capture-720x1280.json'), 'utf8'));
const digest = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
const pause = ms => new Promise(resolve => setTimeout(resolve, ms));
let checks = 0;
const check = (condition, label) => { checks++; assert.ok(condition, label); };
function buttonCenter(view, label) {
  const item = geometry[view].buttons.find(b => typeof label === 'string' ? b.text === label || b.name === label || b.tooltip === label : label.test(b.text));
  assert.ok(item, `Native ${view} has button ${label}`);
  return [item.rect[0] + item.rect[2] / 2, item.rect[1] + item.rect[3] / 2];
}

(async () => {
  fs.mkdirSync(output, { recursive: true });
  const browser = await chromium.launch({
    executablePath: process.env.CHROMIUM_BIN || '/usr/bin/chromium', headless: true,
    args: ['--no-sandbox', '--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'],
  });
  const errors = [];
  const observe = page => {
    page.on('pageerror', e => errors.push(e.message));
    page.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });
  };
  const desktop = await browser.newContext({ viewport: { width: 720, height: 1280 } });
  const page = await desktop.newPage();
  observe(page);
  await page.goto(url);
  await pause(3500);
  const snapshot = name => page.screenshot({ path: path.join(output, name + '.png') });
  const boardHash = async () => digest(await page.screenshot({ clip: { x: 40, y: 444, width: 640, height: 600 } }));
  const click = async (x, y) => { await page.mouse.click(x, y); await pause(800); };
  const button = async (view, label) => click(...buttonCenter(view, label));
  await snapshot('game-initial');
  const blueprintButton = geometry['game-01'].buttons.find(b => b.text === 'Blueprint');
  const pressedClip = { x: blueprintButton.rect[0], y: blueprintButton.rect[1], width: blueprintButton.rect[2], height: blueprintButton.rect[3] };
  await page.mouse.move(...buttonCenter('game-01', 'Blueprint'));
  await pause(100);
  const releasedButton = digest(await page.screenshot({ clip: pressedClip }));
  await page.mouse.down();
  await pause(120);
  check(digest(await page.screenshot({ clip: pressedClip })) !== releasedButton, 'Holding a control renders its dimensional pressed state');
  await snapshot('pressed-blueprint');
  await page.mouse.up();
  await pause(800);
  await button('blueprint-1000', 'Back to puzzle');
  const initial = await boardHash();
  await click(260, 649);
  const moved = await boardHash();
  check(moved !== initial, 'A real board click must remove a visible screw');
  await button('game-01', 'Undo');
  check(await boardHash() === initial, 'Undo must visually restore the whole board');
  await click(260, 649);
  await pause(600);
  await page.reload();
  await pause(3500);
  check(await boardHash() === moved, 'A fresh Web runtime must restore the saved move');
  for (const [x, y] of [[360,649], [460,649], [260,839], [360,839], [460,839]]) await click(x,y);
  await pause(1800); // Let victory particles settle before examining modal controls.
  await snapshot('victory');
  await button('victory', 'My collection');
  await snapshot('collection');
  await button('collection', '‹  Workshop');
  await snapshot('workshop');
  await button('home', 'Continue your craft   ›');
  await button('victory', /^Next /);
  const second = await boardHash();
  check(second !== initial && second !== moved, 'Continue after Collection restores a working Next puzzle button');
  await snapshot('level-02');
  await button('game-01', 'Workshop home');
  await button('home', /Explore|Adventure|1,000|Level map/);
  await button('levels-01', 'Last');
  await snapshot('level-shelf-1000');
  await button('levels-40', /^1000/);
  check(await boardHash() !== second, 'Last map page opens level 1,000');
  await snapshot('level-1000');
  await button('game-1000', 'Blueprint');
  await snapshot('blueprint-1000');
  const blueprint = await boardHash();
  await click(320, 760);
  check(await boardHash() === blueprint, 'Blueprint tap is read-only');
  await button('blueprint-1000', 'Back to puzzle');
  await button('game-01', 'Settings');
  await snapshot('settings');
  await desktop.close();

  const phone = await browser.newContext({ viewport: { width: 360, height: 800 }, hasTouch: true, isMobile: true });
  const touchPage = await phone.newPage();
  observe(touchPage);
  await touchPage.goto(url);
  await pause(3500);
  const phoneBoard = async () => digest(await touchPage.screenshot({ clip: { x: 20, y: 302, width: 320, height: 300 } }));
  const untouched = await phoneBoard();
  await touchPage.touchscreen.tap(130, 404.5); // 720x1280 logical stage centered at y80.
  await pause(800);
  check(await phoneBoard() !== untouched, 'Real phone touch input must remove one screw');
  const undo = buttonCenter('game-01', 'Undo');
  await touchPage.touchscreen.tap(undo[0] / 2, 80 + undo[1] / 2);
  await pause(800);
  check(await phoneBoard() === untouched, 'Phone touch must operate the native Undo button');
  await touchPage.screenshot({ path: path.join(output, 'phone-360x800.png') });
  await phone.close();

  const tablet = await browser.newContext({ viewport: { width: 768, height: 1024 }, hasTouch: true });
  const tabletPage = await tablet.newPage();
  observe(tabletPage);
  await tabletPage.goto(url);
  await pause(3500);
  const tabletBoard = async () => digest(await tabletPage.screenshot({ clip: { x: 128, y: 355, width: 512, height: 480 } }));
  const tabletInitial = await tabletBoard();
  await tabletPage.touchscreen.tap(96 + 260 * 0.8, 649 * 0.8);
  await pause(800);
  check(await tabletBoard() !== tabletInitial, 'Tablet touch respects centered portrait stage geometry');
  await tabletPage.touchscreen.tap(96 + undo[0] * 0.8, undo[1] * 0.8);
  await pause(800);
  check(await tabletBoard() === tabletInitial, 'Tablet Undo restores board without resize drift');
  await tabletPage.screenshot({ path: path.join(output, 'tablet-768x1024.png') });
  await tablet.close();
  await browser.close();
  check(errors.length === 0, 'No Web engine or browser errors: ' + errors.join('\n'));
  const report = { status: 'PASS', checks, platform: 'Chromium software WebGL', actual_touch_events: true,
    viewport_sizes: ['720x1280', '360x800', '768x1024'], errors,
    scope: 'Actual rendered clicks/touch, undo, reload persistence, result navigation, final campaign page and read-only Blueprint. Not a physical phone test.' };
  fs.writeFileSync(path.join(output, 'web-smoke.json'), JSON.stringify(report, null, 2) + '\n');
  console.log(JSON.stringify(report));
})().catch(error => { console.error(error); process.exit(1); });
