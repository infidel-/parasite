// dev tooling: evaluate JS in the running Parasite game over CDP, print result.
// usage: node probe.mjs "<js expression>"
const HOST = '172.18.208.1:9300';
const expr = process.argv[2] || '1';

const targets = await (await fetch(`http://${HOST}/json`)).json();
const page = targets.find(t => t.type === 'page' && t.url.startsWith('file:') && t.url.includes('app.html'));
if (!page) { console.error('no app.html page target'); process.exit(1); }

const ws = new WebSocket(page.webSocketDebuggerUrl);
let id = 0;
const pending = new Map();
const send = (method, params = {}) =>
  new Promise(res => { const i = ++id; pending.set(i, res); ws.send(JSON.stringify({ id: i, method, params })); });
ws.onmessage = e => {
  const m = JSON.parse(e.data);
  if (m.id && pending.has(m.id)) { pending.get(m.id)(m); pending.delete(m.id); }
};
const fail = setTimeout(() => { console.error('timed out'); process.exit(2); }, 15000);
ws.onopen = async () => {
  const r = await send('Runtime.evaluate', { expression: expr, returnByValue: true, awaitPromise: true });
  clearTimeout(fail);
  if (r.result && r.result.exceptionDetails)
    console.log('EXCEPTION:', JSON.stringify(r.result.exceptionDetails, null, 1));
  else
    console.log(typeof r.result.result.value === 'string' ? r.result.result.value : JSON.stringify(r.result.result.value, null, 1));
  process.exit(0);
};
ws.onerror = e => { console.error('ws error', e.message || e); process.exit(4); };
