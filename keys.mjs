// dev tooling: dispatch a sequence of key presses to the running Parasite renderer over CDP.
//
// usage: node keys.mjs <key|+delayMs>...    e.g. node keys.mjs Backquote +500 9
//        node keys.mjs Shift+1              the bloom-alone A/B toggle
//
// a delay is written with a leading + (`+800`). It used to be a bare integer, which made every
// digit key unpressable except in first position — and the digits ARE the in-engine debug keys
// (1 lighting, 2/3/4 fill, 5 spotlights, 6 emissive, 9 draw-call dump). The keys the game reads
// are matched on e.code, so `code` is the field that has to be right; Shift+N sets modifiers 8,
// which is what View.hx's `e.shiftKey && e.code == 'Digit1'` pair needs.
import { connect } from './tools/cdp.mjs';

const args = process.argv.slice(2);
if (!args.length) {
  console.error('usage: node keys.mjs <key|+delayMs>...   e.g. node keys.mjs Backquote +500 9');
  process.exit(1);
}

const named = {
  ArrowDown: { key: 'ArrowDown', code: 'ArrowDown', windowsVirtualKeyCode: 40 },
  ArrowUp: { key: 'ArrowUp', code: 'ArrowUp', windowsVirtualKeyCode: 38 },
  ArrowLeft: { key: 'ArrowLeft', code: 'ArrowLeft', windowsVirtualKeyCode: 37 },
  ArrowRight: { key: 'ArrowRight', code: 'ArrowRight', windowsVirtualKeyCode: 39 },
  Enter: { key: 'Enter', code: 'Enter', windowsVirtualKeyCode: 13 },
  Escape: { key: 'Escape', code: 'Escape', windowsVirtualKeyCode: 27 },
  // the street-debug gate: one press builds window.__dbg and hands the keyboard to the fly-cam
  Backquote: { key: '`', code: 'Backquote', windowsVirtualKeyCode: 192 },
};

const keyInfo = k => {
  if (named[k]) return named[k];
  if (/^F\d+$/.test(k)) return { key: k, code: k, windowsVirtualKeyCode: 0x70 + (parseInt(k.slice(1)) - 1) };
  if (/^\d$/.test(k)) return { key: k, code: 'Digit' + k, windowsVirtualKeyCode: 0x30 + parseInt(k), text: k };
  const u = k.toUpperCase();
  return { key: k, code: 'Key' + u, windowsVirtualKeyCode: u.charCodeAt(0), text: k };
};

const cdp = await connect({ timeoutMs: 30000 });
const wait = ms => new Promise(r => setTimeout(r, ms));

for (const a of args) {
  if (/^\+\d+$/.test(a)) {
    await wait(parseInt(a.slice(1)));
    continue;
  }
  // Shift+N: the game tests e.shiftKey next to e.code, so the modifier bit is what carries it
  const shift = a.startsWith('Shift+');
  const info = keyInfo(shift ? a.slice(6) : a);
  const ev = shift ? { ...info, modifiers: 8 } : info;
  await cdp.send('Input.dispatchKeyEvent', { type: 'keyDown', ...ev });
  await cdp.send('Input.dispatchKeyEvent', { type: 'keyUp', ...ev });
  console.log('pressed', a);
}

cdp.close();
process.exit(0);
