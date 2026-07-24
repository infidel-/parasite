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

// returns every source cell for one gender, including explicitly positioned specials.
function cellsFor(type, gender)
{
  const svgDir = join(SRC, type.svgDir);
  const genderDir = join(SRC, type.genderDirs[gender]);
  const cells = readdirSync(genderDir)
    .map(name => name.replace(/\.[^.]+$/, ''))
    .filter(name => existsSync(join(svgDir, name + '.svg')))
    .sort((a, b) => a.localeCompare(b, undefined, { numeric: true }))
    .map((name, index) => ({
      src: type.svgDir + '/' + name + '.svg',
      x: index % type.cols,
      y: Math.floor(index / type.cols),
    }));
  return cells.concat(type.specials?.[gender] ?? []);
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
    svg = svg.replace(new RegExp('#' + skin.src[i], 'gi'), '#' + skin[variant][i]);
  const raster = await sharp(Buffer.from(svg))
    .resize(type.tile, type.tile)
    .ensureAlpha()
    .raw()
    .toBuffer({ resolveWithObject: true });
  for (let p = 0; p < raster.data.length; p += raster.info.channels)
    for (let i = 0; i < skin.src.length; i++)
      {
        const color = parseInt(skin.src[i], 16);
        if (raster.data[p] === ((color >> 16) & 255)
            && raster.data[p + 1] === ((color >> 8) & 255)
            && raster.data[p + 2] === (color & 255))
          {
            const target = parseInt(skin[variant][i], 16);
            raster.data[p] = target >> 16;
            raster.data[p + 1] = (target >> 8) & 255;
            raster.data[p + 2] = target & 255;
          }
      }
  return sharp(raster.data, {
      raw: {
        width: raster.info.width,
        height: raster.info.height,
        channels: raster.info.channels,
      },
    })
    .modulate({ saturation: info.saturation })
    .png()
    .toBuffer();
}

// builds or updates one gender/skin atlas, reusing unchanged cells from its old output.
async function buildAtlas(type, info, gender, variant, cells, changed, full)
{
  const suffix = variantSuffix(variant);
  const out = join(OUT, gender + suffix + type.tile + '.png');
  const width = type.cols * type.tile;
  const height = Math.max(...cells.map(cell => cell.y + 1)) * type.tile;
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
  const draw = rebuild ? cells : changed;
  const tiles = await Promise.all(draw.map(async cell =>
    {
      return {
        input: await rasterize(join(SRC, cell.src), type, info, variant),
        left: cell.x * type.tile,
        top: cell.y * type.tile,
      };
    }));
  const composites = rebuild
    ? tiles
    : tiles.flatMap(tile => [
      {
        input: Buffer.alloc(type.tile * type.tile * 4, 255),
        raw: {
          width: type.tile,
          height: type.tile,
          channels: 4,
        },
        blend: 'dest-out',
        left: tile.left,
        top: tile.top,
      },
      tile,
    ]);
  writeFileSync(out, await image.composite(composites).png().toBuffer());
  console.log('  built ' + gender + suffix + type.tile + '.png  ' + draw.length + ' tile(s)');
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
      const cells = Object.fromEntries(genders.map(gender => [gender, cellsFor(type, gender)]));
      const signature = createHash('sha256').update(JSON.stringify({
        cells,
        cols: type.cols,
        tile: type.tile,
        saturation: info.saturation,
        skin: info.skin,
      })).digest('hex');
      const allCells = genders.flatMap(gender => cells[gender]);
      const changed = allCells.filter(cell =>
        {
          return info.sources[cell.src] !== sourceStamp(join(SRC, cell.src));
        });
      const full = type.last_sig !== signature;

      for (const gender of genders)
        for (const variant of Object.keys(info.skin))
          {
            if (await buildAtlas(type, info, gender, variant, cells[gender], changed.filter(cell => cells[gender].includes(cell)), full))
              built++;
          }

      for (const cell of allCells)
        {
          info.sources[cell.src] = sourceStamp(join(SRC, cell.src));
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
