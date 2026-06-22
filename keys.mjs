// dev tooling: dispatch a sequence of key presses to the running Parasite renderer over CDP.
// usage: node keys.mjs <key> [delayMs] [key delayMs]...   e.g. node keys.mjs 2 1500 F3 800
const HOST = '172.18.208.1:9300';
const args = process.argv.slice(2);

const targets = await (await fetch(`http://${HOST}/json`)).json();
const page = targets.find(t => t.type === 'page' && t.url.includes('app.html'));
if (!page) { console.error('no app.html page target'); process.exit(1); }

const ws = new WebSocket(page.webSocketDebuggerUrl);
let id = 0;
const pending = new Map();
const send = (method, params = {}) =>
  new Promise(res => { const i = ++id; pending.set(i, res); ws.send(JSON.stringify({ id: i, method, params })); });
ws.onmessage = e => { const m = JSON.parse(e.data); if (m.id && pending.has(m.id)) { pending.get(m.id)(m); pending.delete(m.id); } };
const wait = ms => new Promise(r => setTimeout(r, ms));

const named = {
  ArrowDown: { key: 'ArrowDown', code: 'ArrowDown', windowsVirtualKeyCode: 40 },
  ArrowUp: { key: 'ArrowUp', code: 'ArrowUp', windowsVirtualKeyCode: 38 },
  Enter: { key: 'Enter', code: 'Enter', windowsVirtualKeyCode: 13 },
};
const keyInfo = k => {
  if (named[k]) return named[k];
  if (/^F\d+$/.test(k)) return { key: k, code: k, windowsVirtualKeyCode: 0x70 + (parseInt(k.slice(1)) - 1) };
  if (/^\d$/.test(k)) return { key: k, code: 'Digit' + k, windowsVirtualKeyCode: 0x30 + parseInt(k), text: k };
  return { key: k, code: 'Key' + k.toUpperCase() };
};

ws.onopen = async () => {
  for (let i = 0; i < args.length; i++) {
    const a = args[i];
    if (/^\d+$/.test(a) && i > 0) { await wait(parseInt(a)); continue; }
    const info = keyInfo(a);
    await send('Input.dispatchKeyEvent', { type: 'keyDown', ...info });
    await send('Input.dispatchKeyEvent', { type: 'keyUp', ...info });
    console.log('pressed', a);
  }
  process.exit(0);
};
ws.onerror = e => { console.error('ws error', e.message || e); process.exit(4); };
