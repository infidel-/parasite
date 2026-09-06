// dev tooling: evaluate JS in the running Parasite game over CDP, print result.
// usage: node probe.mjs "<js expression>"
//        node probe.mjs --wait "<js expression>" [timeoutMs]   poll until truthy, print elapsed
// --wait is the primitive that replaces a sleep: "until the area rebuilt", "until __facility()
// answers", "until the fader lifted". It exits 2 on timeout, so it chains with && in a shell.
import { connect, evaluate, waitFor } from './tools/cdp.mjs';

const args = process.argv.slice(2);

if (args[0] === '--wait') {
  const expr = args[1] || '1';
  const ms = parseInt(args[2] || '30000');
  const cdp = await connect({ timeoutMs: 0 });
  const t = await waitFor(cdp, expr, ms);
  cdp.close();
  if (t < 0) {
    console.error(`timed out after ${ms}ms waiting for: ${expr}`);
    process.exit(2);
  }
  console.log(`ready in ${t}ms`);
  process.exit(0);
}

const cdp = await connect({ timeoutMs: 15000 });
try {
  const v = await evaluate(cdp, args[0] || '1');
  console.log(typeof v === 'string' ? v : JSON.stringify(v, null, 1));
}
catch (e) {
  console.log('EXCEPTION:', e.message);
}
cdp.close();
process.exit(0);
