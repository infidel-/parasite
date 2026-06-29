// Publish or update a Parasite mod as a Steam Workshop item.
// Usage: node publish-workshop.js <mod-dir> [itemId]
//   - <mod-dir>: absolute path to mod folder (must contain manifest.json)
//   - [itemId]: optional override. Otherwise read from <mod-dir>/.workshop-id;
//     if neither exists, creates a new item and writes its id to .workshop-id.
// Requires: Steam client running and logged in. App 1920320 must have
// Workshop enabled in Steamworks partner backend.
// New items are created Unlisted (visibility=3); only you see them until
// you change visibility on the Steam Community page.

const fs = require('fs');
const path = require('path');

const APPID = 1920320;

const argv = process.argv.slice(2);
// split positional args from --flags so flags can appear anywhere on the line.
const args = argv.filter(a => !a.startsWith('-'));
const flags = argv.filter(a => a.startsWith('-'));
if (args.length < 1 || flags.includes('-h') || flags.includes('--help')) {
  const help = [
    'Publish or update a Parasite mod as a Steam Workshop item.',
    '',
    'Usage:',
    '  node publish-workshop.js <mod-dir> [itemId] [--fields=a,b,c]',
    '',
    'Arguments:',
    '  <mod-dir>   path to mod folder (must contain manifest.json)',
    '  [itemId]    optional Workshop item id override. Otherwise read from',
    '              <mod-dir>/.workshop-id; if absent, creates a new item and',
    '              writes the new id to .workshop-id.',
    '',
    'Options:',
    '  --fields=LIST  restrict update payload to listed fields (content is',
    '                 always uploaded). Valid: title, changeNote, description,',
    '                 preview, tags, visibility. Default: all available.',
    '  -h, --help     show this help and exit',
    '',
    'Manifest fields used:',
    '  name         -> Workshop title (falls back to id, then "Untitled mod")',
    '  description  -> Workshop description (optional)',
    '  preview      -> path (relative to mod dir) to preview image, PNG/JPG',
    '                  <=1MB. If absent, preview.png or preview.jpg in the mod',
    '                  dir is used when present.',
    '  tags         -> array of Workshop tags. Must match this app\'s',
    '                  Ready-to-Use Item Tags defined in the Steamworks backend;',
    '                  invalid tags are rejected at submit. Optional.',
    '',
    'Requirements:',
    '  Steam client running and logged in. App 1920320 must have Workshop',
    '  enabled in the Steamworks partner backend. Run from app/ so that',
    '  node_modules/steamworks.js resolves.',
    '',
    'New items are created Unlisted (visibility=3); only you see them until',
    'you change visibility on the Steam Community page.',
  ].join('\n');
  console.log(help);
  process.exit(args.length < 1 ? 2 : 0);
}
const fieldsArg = flags.find(a => a.startsWith('--fields='));
const modDir = path.resolve(args[0]);
const idFile = path.join(modDir, '.workshop-id');

const manifestPath = path.join(modDir, 'manifest.json');
if (!fs.existsSync(manifestPath)) {
  console.error('manifest.json not found at ' + manifestPath);
  process.exit(2);
}
const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
const title = manifest.name || manifest.id || 'Untitled mod';
const description = manifest.description || null;
// workshop tags must be pre-defined in Steamworks backend (Ready-to-Use Item
// Tags) for this app; invalid tags are rejected at submit. empty/missing = skip.
const tags = Array.isArray(manifest.tags) && manifest.tags.length
  ? manifest.tags
  : null;
const changeNote = 'Published via publish-workshop.js at ' + new Date().toISOString();

let existingItemId = null;
if (args[1]) existingItemId = BigInt(args[1]);
else if (fs.existsSync(idFile)) {
  const raw = fs.readFileSync(idFile, 'utf8').trim();
  if (raw) existingItemId = BigInt(raw);
}

let steamworks;
try { steamworks = require('steamworks.js'); }
catch (e) {
  console.error('require(steamworks.js) failed:', e.message);
  console.error('Run from app/scripts/ so node_modules/steamworks.js resolves.');
  process.exit(1);
}

let client;
try { client = steamworks.init(APPID); }
catch (e) {
  console.error('steamworks.init failed:', e.message);
  console.error('Is the Steam client running and logged in?');
  process.exit(1);
}
console.log('[steam] init OK (appid=' + APPID + ')');

(async () => {
  let itemId = existingItemId;
  let isNew = false;
  if (itemId == null) {
    console.log('[workshop] createItem...');
    const created = await client.workshop.createItem(APPID);
    itemId = created.itemId;
    isNew = true;
    fs.writeFileSync(idFile, itemId.toString() + '\n');
    console.log('[workshop] created itemId=' + itemId.toString() +
      ' (saved to ' + idFile + ')' +
      ' needsToAcceptAgreement=' + created.needsToAcceptAgreement);
    if (created.needsToAcceptAgreement) {
      console.log('[workshop] open this URL, accept agreement, then re-run:');
      console.log('  https://steamcommunity.com/sharedfiles/filedetails/?id=' + itemId.toString());
      process.exit(0);
    }
  }
  else {
    console.log('[workshop] reusing itemId=' + itemId.toString() +
      (args[1] ? ' (cli)' : ' (from .workshop-id)'));
  }

  // --fields=a,b,c restricts to listed fields. Always includes contentPath.
  //   valid: title,changeNote,description,preview,tags,visibility
  //   default (no flag): all available
  const allow = fieldsArg
    ? new Set(fieldsArg.substr(9).split(',').map(s => s.trim()).filter(Boolean))
    : null;
  const want = (k) => allow == null || allow.has(k);
  // resolve preview image: manifest.preview wins, else preview.png/jpg in mod dir.
  // steam cap 1MB PNG/JPG. uploads on every call when set; gate via --fields=.
  const preview = manifest.preview
    ? path.resolve(modDir, manifest.preview)
    : ['preview.png', 'preview.jpg'].map(f => path.join(modDir, f)).find(fs.existsSync);
  const update = { contentPath: modDir };
  if (want('title')) update.title = title;
  if (want('changeNote')) update.changeNote = changeNote;
  if (want('description') && description) update.description = description;
  if (want('preview') && preview) update.previewPath = preview;
  // SetItemTags replaces the full tag list each call, so always send all of them.
  if (want('tags') && tags) update.tags = tags;
  if (want('visibility') && isNew) update.visibility = 3;
  console.log('[workshop] updateItem payload:', JSON.stringify(update));
  // post-createItem Steam item state can be flaky for ~10-30s: SubmitItemUpdate
  // returns 'method busy' or 'a parameter is invalid' until backend settles.
  // retry both, otherwise fail fast.
  const transient = (msg) =>
    /method busy|a parameter is invalid/i.test(String(msg || ''));
  let result;
  let attempt = 0;
  while (true) {
    try { result = await client.workshop.updateItem(itemId, update, APPID); break; }
    catch (e) {
      attempt++;
      if (attempt > 3 || !transient(e && e.message)) throw e;
      const delay = 5000 * attempt;
      console.warn('[workshop] updateItem transient err (' + e.message +
        '), retry ' + attempt + '/3 in ' + (delay / 1000) + 's...');
      await new Promise(r => setTimeout(r, delay));
    }
  }
  console.log('[workshop] update OK itemId=' + result.itemId.toString());
  console.log('[workshop] subscribe URL:');
  console.log('  steam://url/CommunityFilePage/' + result.itemId.toString());
  console.log('  https://steamcommunity.com/sharedfiles/filedetails/?id=' + result.itemId.toString());
  process.exit(0);
})().catch(e => {
  console.error('[workshop] failed:', e);
  process.exit(1);
});
