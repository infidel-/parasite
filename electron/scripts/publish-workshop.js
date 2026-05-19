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

const args = process.argv.slice(2);
if (args.length < 1) {
  console.error('Usage: node publish-workshop.js <mod-dir> [itemId]');
  process.exit(2);
}
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
  //   valid: title,changeNote,description,visibility
  //   default (no flag): all available
  const fieldsArg = process.argv.find(a => a.startsWith('--fields='));
  const allow = fieldsArg
    ? new Set(fieldsArg.substr(9).split(',').map(s => s.trim()).filter(Boolean))
    : null;
  const want = (k) => allow == null || allow.has(k);
  const update = { contentPath: modDir };
  if (want('title')) update.title = title;
  if (want('changeNote')) update.changeNote = changeNote;
  if (want('description') && description) update.description = description;
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
