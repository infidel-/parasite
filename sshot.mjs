// dev tooling: screenshot the running Parasite Electron game over CDP.
// bypasses chrome-devtools-mcp (which waits for page-idle and hangs on the game loop)
// and forces a frame commit via a metrics override so capture works even when the
// in-game scene is static / the window isn't foreground.
// usage: make sshot   (writes sshot.jpg)   |   node sshot.mjs [outpath]
import { writeFileSync } from 'node:fs';

const HOST = '172.18.208.1:9300';
const out = process.argv[2] || 'sshot.jpg';

const targets = await (await fetch(`http://${HOST}/json`)).json();
const page = targets.find(t => t.type === 'page' && t.url.startsWith('file:') && t.url.includes('app.html'));
if (!page) { console.error('no app.html page target — is the game running with --remote-debugging-port=9300?'); process.exit(1); }

const ws = new WebSocket(page.webSocketDebuggerUrl);
let id = 0;
const pending = new Map();
const send = (method, params = {}) =>
  new Promise(res => { const i = ++id; pending.set(i, res); ws.send(JSON.stringify({ id: i, method, params })); });
ws.onmessage = e => {
  const m = JSON.parse(e.data);
  if (m.id && pending.has(m.id)) { pending.get(m.id)(m); pending.delete(m.id); }
};

const fail = setTimeout(() => { console.error('capture timed out'); process.exit(2); }, 20000);
ws.onopen = async () => {
  const lm = (await send('Page.getLayoutMetrics')).result;
  const vp = lm.cssVisualViewport || lm.layoutViewport;
  const w = Math.round(vp.clientWidth), h = Math.round(vp.clientHeight);
  // metrics override -> forces relayout + repaint + compositor commit -> fresh frame
  await send('Emulation.setDeviceMetricsOverride', { width: w, height: h, deviceScaleFactor: 1, mobile: false });
  const r = (await send('Page.captureScreenshot', { format: 'jpeg', quality: 55 })).result;
  await send('Emulation.clearDeviceMetricsOverride');
  clearTimeout(fail);
  if (!r || !r.data) { console.error('no screenshot data'); process.exit(3); }
  const buf = Buffer.from(r.data, 'base64');
  writeFileSync(out, buf);
  console.log('wrote', out, Math.round(buf.length / 1024) + 'kb');
  process.exit(0);
};
ws.onerror = e => { console.error('ws error', e.message || e); process.exit(4); };
