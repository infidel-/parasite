// dev tooling: screenshot the running Parasite Electron game over CDP.
// bypasses chrome-devtools-mcp (which waits for page-idle and hangs on the game loop)
// and forces a frame commit via a metrics override so capture works even when the
// in-game scene is static / the window isn't foreground.
// usage: make sshot   (writes sshot.jpg)   |   node sshot.mjs [outpath] [--wait]
// --wait holds off while the fader is opaque: an area enter runs its 3D build under solid black,
// and a capture taken in that window is a black JPEG rather than a stale one.
import { writeFileSync } from 'node:fs';
import { connect, evaluate, waitFor, FADER } from './tools/cdp.mjs';

const args = process.argv.slice(2);
const doWait = args.includes('--wait');
const out = args.find(a => !a.startsWith('--')) || 'sshot.jpg';

const cdp = await connect({ timeoutMs: 0 });

if (doWait && await waitFor(cdp, `${FADER} === '0'`, 90000) < 0) {
  console.error('the fader never lifted — the area is still building');
  cdp.close();
  process.exit(5);
}
else if (!doWait && await evaluate(cdp, FADER) === '1')
  console.error('warning: capturing under an opaque fader — expect a black frame (pass --wait)');

const lm = (await cdp.send('Page.getLayoutMetrics')).result;
const vp = lm.cssVisualViewport || lm.layoutViewport;
const w = Math.round(vp.clientWidth), h = Math.round(vp.clientHeight);
// metrics override -> forces relayout + repaint + compositor commit -> fresh frame
await cdp.send('Emulation.setDeviceMetricsOverride', { width: w, height: h, deviceScaleFactor: 1, mobile: false });
const r = (await cdp.send('Page.captureScreenshot', { format: 'jpeg', quality: 55 })).result;
await cdp.send('Emulation.clearDeviceMetricsOverride');
if (!r || !r.data) {
  console.error('no screenshot data');
  process.exit(3);
}
const buf = Buffer.from(r.data, 'base64');
writeFileSync(out, buf);
console.log('wrote', out, Math.round(buf.length / 1024) + 'kb');
cdp.close();
process.exit(0);
