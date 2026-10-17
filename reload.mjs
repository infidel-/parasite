// dev tooling: reload the running Parasite Electron renderer over CDP.
// the running renderer does NOT hot-reload after `make` copies new artifacts into app/, so call
// this to pull in CSS/JS/HTML changes.
//
// a bare reload lands on the main menu, which is why `make reload` alone leaves __facility() and
// friends reading nothing: no area has been built. `--load` carries on through the boot — it waits
// for the warm to settle, answers the "Autosave exists. Load?" offer MainMenu puts up 1ms later
// (or loads a named slot instead), and returns only once the first frame has actually presented.
// The reload itself is what makes that autosave current: Main's beforeunload flushes a forced
// autosave, and Page.reload fires it.
//
// usage: make reload   |   make reload-load [slot=N]   |   node reload.mjs [--load [slot]] [--verbose]
import { connect, evaluate, waitFor, GAME, UISTATE, state, FADER } from './tools/cdp.mjs';

const args = process.argv.slice(2);
const doLoad = args.includes('--load');
const verbose = args.includes('--verbose');
const slotArg = args[args.indexOf('--load') + 1];
const slot = /^\d+$/.test(slotArg || '') ? parseInt(slotArg) : null;

const cdp = await connect({ timeoutMs: 0 });
const t0 = Date.now();
const at = () => ((Date.now() - t0) / 1000).toFixed(1) + 's';
const die = (msg, code = 3) => { console.error(msg); cdp.close(); process.exit(code); };

// the game reports its own boot timings — [street-warmup] carries the warm ms and program count.
// Nothing here has ever been able to read them; they are the whole reason the event side of
// tools/cdp.mjs exists. The mod loader narrates ~40 lines per boot, so it is --verbose only.
let echo = false;
cdp.on('Runtime.consoleAPICalled', p => {
  if (!echo) return;
  const s = (p.args || []).map(a => a.value).filter(v => typeof v === 'string').join(' ');
  if (s.startsWith('[street-warmup]') || verbose || /fail|error/i.test(s))
    console.log('  ' + s);
});
await cdp.send('Runtime.enable');
await cdp.send('Page.enable');
// Runtime.enable replays the OUTGOING context's buffered console, which would print the previous
// session's whole boot before this one starts. Let that drain before echoing anything.
// ponytail: a settle rather than filtering on executionContextId — the replay is synchronous in
// practice; if a line ever leaks through, switch to the id from Runtime.executionContextCreated.
await new Promise(r => setTimeout(r, 250));
echo = true;
// mark the outgoing page: Page.reload returns before it dies, and one sitting at the menu or the
// offer would otherwise answer the wait below
await evaluate(cdp, 'window.__reloading = true');
await cdp.send('Page.reload', { ignoreCache: true });
console.log('reloaded', cdp.page.url);

if (!doLoad) {
  // the old script exited here without even waiting for the load event
  cdp.close();
  process.exit(0);
}

// reveal() in Main is the only thing that sets MAINMENU, and it fires on every path the warm can
// take — resolved, failed, or the 30s backstop it arms. The warm's own cost is in the
// [street-warmup] line echoed above; do not carry a remembered number, it moves with the machine.
// the autosave offer replaces MAINMENU one tick later, which a 100ms poll misses, so it counts too
if (await waitFor(cdp, `!window.__reloading && ((${state('UISTATE_MAINMENU')}) || (${state('UISTATE_YESNO')}))`, 60000) < 0)
  die('never reached the main menu — warm stuck, or the page did not come back');
console.log(`menu at ${at()}`);

if (slot !== null) {
  // explicit slot: step over the offer the menu is about to raise and go straight in, the way
  // Saves.doLoad does (close first, so the load's fader.cover paints in sync with the 3D build)
  await evaluate(cdp, `(g => { g.ui.closeWindow(); g.ui.canvas.style.visibility = 'visible'; g.load(${slot}); })(${GAME})`);
  console.log(`load(${slot})`);
}
else {
  // the boot autosave offer, armed by MainMenu.update and opened one tick later
  if (await waitFor(cdp, state('UISTATE_YESNO'), 5000) < 0)
    die('no autosave offer appeared — is there a save00.json? (pass a slot: --load 1)');
  const text = await evaluate(cdp, "(document.getElementById('window-yesno').innerText || '').replace(/\\s+/g, ' ')");
  if (!text.includes('Autosave exists'))
    die(`unexpected dialog at the menu: ${text}`);
  // click the button rather than pressing a key: UI.pressButton defers the synthetic click 130ms
  await evaluate(cdp, "document.getElementById('window-yesno-yes').click()");
  console.log('accepted the autosave offer');
}

// the load runs under the fader, so the cover going opaque is the signal it actually started —
// but Loader.load is fully SYNCHRONOUS and blocks the thread before draw3D ever gets to cover, so
// this window has to clear a big save's parse, not just a frame.
// if it never covers, the likeliest cause is the mod-diff prompt Game.load raises when the enabled
// mod set differs from the save's snapshot — one that has resisted both a DOM click and a CDP key
if (await waitFor(cdp, `${FADER} === '1'`, 20000) < 0) {
  const st = await evaluate(cdp, UISTATE);
  if (st === 'UISTATE_YESNO') {
    const text = await evaluate(cdp, "(document.getElementById('window-yesno').innerText || '').replace(/\\s+/g, ' ')");
    die(`load blocked by a dialog (answer it by hand): ${text}`);
  }
  die(`load never started — ui.state is ${st}`);
}

// back to transparent only from View's firstFrame callback. A facility or sewer pays its own
// warmKind here too (0.3-1.7s), under the same black cover.
if (await waitFor(cdp, `${GAME}.isStarted && ${FADER} === '0'`, 90000) < 0)
  die('the area never presented a frame');
console.log(`in-game at ${at()}`);

cdp.close();
process.exit(0);
