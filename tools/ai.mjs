// AI sprite bake: profession SVGs -> partial 128px gender atlases.
import sharp from 'sharp';
import { createHash } from 'node:crypto';
import { existsSync, mkdirSync, readFileSync, readdirSync, statSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const SRC = join(ROOT, 'ai-src');
const OUT = join(ROOT, 'parasite/resources/app/img');
const INFO = join(SRC, 'ai.json');

// returns a stable timestamp for a source file.
function sourceStamp(path)
{
  return Math.floor(statSync(path).mtimeMs);
}

// returns gender-ordered SVG source names from the old PNG atlas membership.
function sourcesFor(type, gender)
{
  const svgDir = join(SRC, type.svgDir);
  const genderDir = join(SRC, type.genderDirs[gender]);
  return readdirSync(genderDir)
    .map(name => name.replace(/\.[^.]+$/, ''))
    .filter(name => existsSync(join(svgDir, name + '.svg')))
    .sort((a, b) => a.localeCompare(b, undefined, { numeric: true }));
}

// returns the output filename suffix for a skin variant.
function variantSuffix(variant)
{
  return variant === 'src' ? '' : '-' + variant;
}

// rasterizes one source SVG with one skin palette.
async function rasterize(path, type, info, variant)
{
  const skin = info.skin;
  let svg = readFileSync(path, 'utf8');
  for (let i = 0; i < skin.src.length; i++)
    svg = svg.replaceAll('#' + skin.src[i], '#' + skin[variant][i]);
  return sharp(Buffer.from(svg))
    .resize(type.tile, type.tile)
    .modulate({ saturation: info.saturation })
    .png()
    .toBuffer();
}

// builds or updates one gender/skin atlas, reusing unchanged cells from its old output.
async function buildAtlas(type, info, gender, variant, names, changed, full)
{
  const suffix = variantSuffix(variant);
  const out = join(OUT, gender + suffix + type.tile + '.png');
  const width = type.cols * type.tile;
  const height = Math.ceil(names.length / type.cols) * type.tile;
  const rebuild = full || !existsSync(out);
  if (!rebuild && changed.length === 0)
    {
      console.log('  up to date ' + gender + suffix + type.tile + '.png');
      return false;
    }
  const image = rebuild
    ? sharp({
      create: {
        width,
        height,
        channels: 4,
        background: { r: 0, g: 0, b: 0, alpha: 0 },
      },
    })
    : sharp(out);
  const cells = rebuild ? names : changed;
  const composites = await Promise.all(cells.map(async name =>
    {
      const index = names.indexOf(name);
      return {
        input: await rasterize(join(SRC, type.svgDir, name + '.svg'), type, info, variant),
        left: (index % type.cols) * type.tile,
        top: Math.floor(index / type.cols) * type.tile,
      };
    }));
  writeFileSync(out, await image.composite(composites).png().toBuffer());
  console.log('  built ' + gender + suffix + type.tile + '.png  ' + cells.length + ' tile(s)');
  return true;
}

// builds every configured type and updates the source-mtime manifest.
async function main()
{
  if (!existsSync(INFO))
    throw new Error('missing ' + INFO);
  const info = JSON.parse(readFileSync(INFO, 'utf8'));
  info.sources ??= {};
  mkdirSync(OUT, { recursive: true });
  let built = 0;

  for (const type of Object.values(info.types))
    {
      const genders = Object.keys(type.genderDirs);
      const names = Object.fromEntries(genders.map(gender => [gender, sourcesFor(type, gender)]));
      const signature = createHash('sha256').update(JSON.stringify({
        names,
        cols: type.cols,
        tile: type.tile,
        saturation: info.saturation,
        skin: info.skin,
      })).digest('hex');
      const allNames = [...new Set(genders.flatMap(gender => names[gender]))];
      const changed = allNames.filter(name =>
        {
          const rel = type.svgDir + '/' + name + '.svg';
          return info.sources[rel] !== sourceStamp(join(SRC, rel));
        });
      const full = type.last_sig !== signature;

      for (const gender of genders)
        for (const variant of Object.keys(info.skin))
          {
            if (await buildAtlas(type, info, gender, variant, names[gender], changed.filter(name => names[gender].includes(name)), full))
              built++;
          }

      for (const name of allNames)
        {
          const rel = type.svgDir + '/' + name + '.svg';
          info.sources[rel] = sourceStamp(join(SRC, rel));
        }
      type.last_sig = signature;
    }

  writeFileSync(INFO, JSON.stringify(info, null, 2) + '\n');
  console.log('ai: ' + built + ' atlas(es) built');
}

main().catch(err =>
  {
    console.error('ai: ' + err.message);
    process.exitCode = 1;
  });
