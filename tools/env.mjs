// the repo's `env` file (KEY=value lines, see its header) for the node tools; the twin of tools/env.py.
//   import { ENV, APP } from './env.mjs';  ENV.MODELS_SRC, APP = BUILD/resources/app
import { readFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

export const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..');
// split at the first '=' and strip nothing: the Yandex paths hold a space
export const ENV = Object.fromEntries(readFileSync(join(ROOT, 'env'), 'utf8').split(/\r?\n/)
  .filter((l) => l.includes('=') && !l.startsWith('#'))
  .map((l) => [l.slice(0, l.indexOf('=')), l.slice(l.indexOf('=') + 1)]));
// the electron app dir the build stages into (the docs' app/)
export const APP = join(ENV.BUILD, 'resources', 'app');
