// dev tooling: the CDP session every root script shares — target discovery, the promise-multiplexed
// RPC, and the event fan-out. The first three were copy-pasted into probe/reload/sshot/keys four
// times over, with the WSL->Windows host as a literal in each. The event side is new, and is what
// lets a script read the game's own [street-warmup] / [mods] console lines instead of guessing at
// boot timings.
// host override: PARASITE_CDP=127.0.0.1:9300 node probe.mjs "1"

const HOST = process.env.PARASITE_CDP || '172.18.208.1:9300';

// open a CDP session on the game page. `send` is request/response, `on` subscribes to a CDP event by
// method name, `close` drops the socket. timeoutMs arms a whole-session watchdog; pass 0 for the
// scripts that poll and manage their own deadline.
export async function connect(opts = {}) {
  const host = opts.host || HOST;
  const targets = await (await fetch(`http://${host}/json`)).json();
  // DevTools is a page target too (the install dir has a .debug sentinel, so it auto-opens) —
  // match the game's own file: url
  const page = targets.find(t => t.type === 'page' && t.url.startsWith('file:') && t.url.includes('app.html'));
  if (!page) {
    console.error(`no app.html page target at ${host} — is the game running with --remote-debugging-port=9300?`);
    process.exit(1);
  }

  const ws = new WebSocket(page.webSocketDebuggerUrl);
  let id = 0;
  const pending = new Map();
  const events = new Map();
  ws.onmessage = e => {
    const m = JSON.parse(e.data);
    if (m.id && pending.has(m.id)) {
      pending.get(m.id)(m);
      pending.delete(m.id);
    }
    else if (m.method && events.has(m.method))
      for (const fn of events.get(m.method)) fn(m.params);
  };
  ws.onerror = e => { console.error('ws error', e.message || e); process.exit(4); };

  const ms = opts.timeoutMs === undefined ? 20000 : opts.timeoutMs;
  const fail = ms > 0 ? setTimeout(() => { console.error('timed out'); process.exit(2); }, ms) : null;
  await new Promise(res => { ws.onopen = res; });

  return {
    page,
    send: (method, params = {}) => new Promise(res => {
      const i = ++id;
      pending.set(i, res);
      ws.send(JSON.stringify({ id: i, method, params }));
    }),
    on: (method, fn) => {
      if (!events.has(method)) events.set(method, []);
      events.get(method).push(fn);
    },
    close: () => { if (fail) clearTimeout(fail); ws.close(); },
  };
}

// evaluate an expression in the page and hand back the value. throws on a page-side exception.
export async function evaluate(cdp, expr) {
  const r = await cdp.send('Runtime.evaluate', { expression: expr, returnByValue: true, awaitPromise: true });
  if (r.result && r.result.exceptionDetails)
    throw new Error(JSON.stringify(r.result.exceptionDetails, null, 1));
  return r.result.result.value;
}

// poll an expression until it comes back truthy. returns elapsed ms, or -1 on timeout.
// a reload tears the execution context down mid-poll and an early boot has no parasiteHx yet —
// both read as a throw here, which is a "not yet", not a failure
export async function waitFor(cdp, expr, timeoutMs = 30000, everyMs = 100) {
  const t0 = Date.now();
  while (Date.now() - t0 < timeoutMs) {
    let v = null;
    try { v = await evaluate(cdp, expr); } catch (e) { v = null; }
    if (v) return Date.now() - t0;
    await new Promise(r => setTimeout(r, everyMs));
  }
  return -1;
}

// the live Game singleton, guarded for the window between page load and `new Game()`.
// UIState is a Haxe `enum abstract (String)`, so the state compares against a plain string — but
// UI.state is declared `(get,set)`, which Haxe emits as an ACCESSOR and no field at all: reading
// `.ui.state` from JS returns undefined, silently, and a poll on it would just time out.
export const GAME = "(window.parasiteHx && parasiteHx['game.Game'].inst)";
export const UISTATE = `${GAME} && ${GAME}.ui.get_state()`;
export const state = s => `(${UISTATE}) === '${s}'`;
// the fader's inline opacity is the truest "a frame has actually presented" proxy: it only returns
// to 0 from View's firstFrame callback (GameScene.draw3D <- View.present), or its 5s backstop
export const FADER = "document.getElementById('fader').style.opacity";
