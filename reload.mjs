// dev tooling: reload the running Parasite Electron renderer over CDP.
// the running renderer does NOT hot-reload after `make` copies new artifacts into app/,
// so call this to pull in CSS/JS/HTML changes. note: a bare reload lands on the main menu;
// to verify in-game HUD/window changes the user must still load a save afterward.
// usage: make reload   |   node reload.mjs

const HOST = '172.18.208.1:9300';

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

const fail = setTimeout(() => { console.error('reload timed out'); process.exit(2); }, 10000);
ws.onopen = async () => {
  await send('Page.enable');
  await send('Page.reload', { ignoreCache: true });
  clearTimeout(fail);
  console.log('reloaded', page.url);
  process.exit(0);
};
