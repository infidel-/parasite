// main electron entry-point

import haxe.Json;
import js.Node;
import js.Node.__dirname;
import js.node.Fs;
import js.node.Path;
import electron.main.App;
import electron.main.BrowserWindow;
import electron.main.IpcMain;
import electron.main.Protocol;
import electron.Shell;
import mods.ModInfo;

class MainElectron
{
  // Steam app id — assigned by Valve for "Parasite" on Steam
  static inline var STEAM_APPID = 1920320;

  static var win: BrowserWindow;
  // resolved once at App.ready; all session log writes target this file
  static var logPath: String = null;
  static var sessionEnded: Bool = false;
  // populated by scanMods() at App.ready; served to renderer via host:mods:list
  // also indexed by id for mod:// protocol handler resolution
  static var modsList: Array<ModInfo> = [];
  static var modsByID: haxe.DynamicAccess<ModInfo> = {};
  // steamworks.js native module ref + init status. null = module load failed
  // (missing dep, ABI mismatch); steamClient = null means init failed (no
  // Steam client running, wrong appid, sandbox refused). sideload path stays
  // functional regardless — workshop discovery is best-effort
  static var steamworks: Dynamic = null;
  static var steamClient: Dynamic = null;
  // resolved once at App.ready: true if a .debug sentinel file exists in cwd.
  // gates devtools, native menu, host:debug:* IPC, and propagates to renderer
  // via host:boot return for Const.isDebug
  static var isDebug: Bool = false;

  // size caps (bytes)
  static inline var CAP_SETTINGS = 256 * 1024;
  static inline var CAP_PROFILE  = 1024 * 1024;
  static inline var CAP_HISTORY  = 256 * 1024;
  static inline var CAP_SAVE     = 32 * 1024 * 1024;
  static inline var CAP_META     = 64 * 1024;
  static inline var CAP_LOGLINE  = 4 * 1024;
  static inline var CAP_IMAGE_B64 = 16 * 1024 * 1024;
  static inline var CAP_DEBUG_TEXT = 16 * 1024 * 1024;

// ensure electron user data directory exists
  static function ensureUserDataPath()
    {
      var path = App.getPath('userData');
      if (!Fs.existsSync(path))
        Fs.mkdirSync(path);
    }

// get settings file path
  static function getSettingsPath(): String
    {
      return writablePath('settings.json');
    }

// resolve writable file path: darwin uses electron userData, else cwd
  static function writablePath(filename: String): String
    {
      if (Node.process.platform != 'darwin')
        return filename;
      ensureUserDataPath();
      return Path.join(App.getPath('userData'), filename);
    }

// sound asset dir (matches old Sounds.hx conditional)
  static function soundDir(): String
    {
      if (Node.process.platform == 'darwin')
        return Path.join(App.getAppPath(), 'sound');
      return 'resources/app/sound/';
    }

// debug-only write dir under userData/debug
  static function debugDir(): String
    {
      ensureUserDataPath();
      var dir = Path.join(App.getPath('userData'), 'debug');
      if (!Fs.existsSync(dir))
        Fs.mkdirSync(dir);
      return dir;
    }

// validate slotID is non-negative integer in [0, 999]
  static function isValidSlotID(id: Dynamic): Bool
    {
      if (!Std.isOfType(id, Int))
        return false;
      var n: Int = cast id;
      return n >= 0 && n <= 999;
    }

// validate filename basename: [A-Za-z0-9_.-]{1,64}, no leading dot
  static function isValidBasename(s: Dynamic): Bool
    {
      if (!Std.isOfType(s, String))
        return false;
      var str: String = cast s;
      if (str.length < 1 || str.length > 64)
        return false;
      if (str.charAt(0) == '.')
        return false;
      var re = ~/^[A-Za-z0-9_.\-]+$/;
      return re.match(str);
    }

// validate string is under byte cap
  static function isValidString(s: Dynamic, maxBytes: Int): Bool
    {
      if (!Std.isOfType(s, String))
        return false;
      var str: String = cast s;
      return str.length <= maxBytes;
    }

// compose save file name from slot id
  static function saveFileName(slotID: Int): String
    {
      return 'save' + (slotID < 10 ? '0' : '') + slotID + '.json';
    }

// compose save meta sidecar file name from slot id
  static function saveMetaFileName(slotID: Int): String
    {
      return 'save' + (slotID < 10 ? '0' : '') + slotID + '.meta.json';
    }

// safe file read returning null on any failure
  static function safeReadFile(path: String): String
    {
      try {
        return Fs.readFileSync(path, 'utf8');
      }
      catch (e: Dynamic)
        {
          return null;
        }
    }

// safe exists check
  static function safeExists(path: String): Bool
    {
      try {
        return Fs.existsSync(path);
      }
      catch (e: Dynamic)
        {
          return false;
        }
    }

// safe write returning true/false
  static function safeWriteFile(path: String, data: String): Bool
    {
      try {
        Fs.writeFileSync(path, data, 'utf8');
        return true;
      }
      catch (e: Dynamic)
        {
          trace('write failed for ' + path + ': ' + e);
          return false;
        }
    }

// safe delete returning true/false; missing file counts as success
  static function safeDelete(path: String): Bool
    {
      try {
        if (Fs.existsSync(path))
          Fs.unlinkSync(path);
        return true;
      }
      catch (e: Dynamic)
        {
          trace('delete failed for ' + path + ': ' + e);
          return false;
        }
    }

// pre-ready buffer; flushed by initLogSession once logPath is set
  static var pendingLog: Array<String> = [];

// file-only log; buffers if logPath not yet resolved (pre-ready path)
  static function mlog(line: String)
    {
      if (logPath == null) {
        pendingLog.push(line);
        return;
      }
      try { Fs.appendFileSync(logPath, line + '\n'); }
      catch (e: Dynamic) {}
    }

// validate manifest mod id: lowercase [a-z0-9_-], optional dot segments, 4-80 chars
  static function isValidModID(s: Dynamic): Bool
    {
      if (!Std.isOfType(s, String))
        return false;
      var str: String = cast s;
      if (str.length < 4 || str.length > 80)
        return false;
      var re = ~/^[a-z0-9_\-]+(\.[a-z0-9_\-]+)*$/;
      return re.match(str);
    }

// validate exportGlobal: single-segment JS identifier, 1-64 chars.
// loader does window[exportGlobal] so dotted paths / separators are rejected
  static function isValidExportGlobal(s: Dynamic): Bool
    {
      if (!Std.isOfType(s, String))
        return false;
      var str: String = cast s;
      if (str.length < 1 || str.length > 64)
        return false;
      var re = ~/^[A-Za-z_$][A-Za-z0-9_$]*$/;
      return re.match(str);
    }

// validate semver-ish version: digits + dots, 1-32 chars
  static function isValidVersionStr(s: Dynamic): Bool
    {
      if (!Std.isOfType(s, String))
        return false;
      var str: String = cast s;
      if (str.length < 1 || str.length > 32)
        return false;
      var re = ~/^[0-9A-Za-z.\-]+$/;
      return re.match(str);
    }

// mime lookup for mod:// served files; null on unknown extension
  static function mimeFor(p: String): String
    {
      var lower = p.toLowerCase();
      if (StringTools.endsWith(lower, '.js'))
        return 'text/javascript';
      // .map served as JSON so devtools can fetch entry.js.map and rewrite
      // mod stacks to Entry.hx:LINE (otherwise 415s and stacks stay as entry.js)
      if (StringTools.endsWith(lower, '.json') ||
          StringTools.endsWith(lower, '.map'))
        return 'application/json';
      if (StringTools.endsWith(lower, '.png'))
        return 'image/png';
      if (StringTools.endsWith(lower, '.jpg') ||
          StringTools.endsWith(lower, '.jpeg'))
        return 'image/jpeg';
      if (StringTools.endsWith(lower, '.mp3'))
        return 'audio/mpeg';
      if (StringTools.endsWith(lower, '.css'))
        return 'text/css';
      return null;
    }

// recursively walk <rootDir>/assets/ and collect rel forward-slash paths
// for files with mod-allowed extensions (.png, .mp3). returns [] if no assets dir
  static function walkAssets(rootDir: String): Array<String>
    {
      var out: Array<String> = [];
      var assetsDir = Path.join(rootDir, 'assets');
      if (!safeExists(assetsDir))
        return out;
      function walk(dir: String, prefix: String)
        {
          var entries: Array<String>;
          try { entries = Fs.readdirSync(dir); }
          catch (e: Dynamic) { return; }
          for (name in entries)
            {
              var full = Path.join(dir, name);
              var stat: Dynamic;
              try { stat = Fs.statSync(full); }
              catch (e: Dynamic) { continue; }
              var rel = (prefix.length == 0) ? name : (prefix + '/' + name);
              if (stat.isDirectory())
                walk(full, rel);
              else if (stat.isFile())
                {
                  var lower = name.toLowerCase();
                  if (StringTools.endsWith(lower, '.png') ||
                      StringTools.endsWith(lower, '.jpg') ||
                      StringTools.endsWith(lower, '.jpeg') ||
                      StringTools.endsWith(lower, '.mp3'))
                    out.push(rel);
                }
            }
        }
      walk(assetsDir, '');
      return out;
    }

// parse + validate one mod dir; returns serializable info or null on reject
// reasons logged to console (caller does not bubble individual reasons)
  static function loadManifest(rootDir: String, source: String): ModInfo
    {
      var manifestPath = Path.join(rootDir, 'manifest.json');
      if (!safeExists(manifestPath))
        return null;
      var raw = safeReadFile(manifestPath);
      if (raw == null) {
        mlog('[mods] manifest read failed at ' + manifestPath);
        return null;
      }
      var m: Dynamic = null;
      try { m = Json.parse(raw); }
      catch (e: Dynamic) {
        mlog('[mods] manifest parse failed at ' + manifestPath + ': ' + e);
        return null;
      }
      if (!isValidModID(m.id)) {
        mlog('[mods] invalid id at ' + manifestPath + ': ' + m.id);
        return null;
      }
      if (!isValidVersionStr(m.version)) {
        mlog('[mods] invalid version at ' + manifestPath + ': ' + m.version);
        return null;
      }
      if (!Std.isOfType(m.modApiVersion, Int)) {
        mlog('[mods] missing/invalid modApiVersion at ' + manifestPath);
        return null;
      }
      if (!isValidBasename(m.entry)) {
        mlog('[mods] invalid entry filename at ' + manifestPath + ': ' + m.entry);
        return null;
      }
      var entryAbs = Path.join(rootDir, cast m.entry);
      if (!safeExists(entryAbs)) {
        mlog('[mods] entry file missing: ' + entryAbs);
        return null;
      }
      if (!isValidExportGlobal(m.exportGlobal)) {
        mlog('[mods] missing/invalid exportGlobal at ' + manifestPath + ': ' + m.exportGlobal);
        return null;
      }
      var info: ModInfo = {
        id: m.id,
        name: (m.name != null ? m.name : m.id),
        author: (m.author != null ? m.author : ''),
        version: m.version,
        modApiVersion: m.modApiVersion,
        entry: m.entry,
        exportGlobal: m.exportGlobal,
        rootDir: rootDir,
        source: source,
        minGameVersion: m.minGameVersion,
        dependencies: m.dependencies,
        loadAfter: m.loadAfter,
        loadBefore: m.loadBefore,
        assets: walkAssets(rootDir),
        hasModCss: safeExists(Path.join(rootDir, 'mod.css')),
      };
      return info;
    }

// scan a base dir (e.g. cwd/mods); each child dir = candidate mod
  static function scanBaseDir(base: String, source: String, out: Array<ModInfo>, byID: haxe.DynamicAccess<ModInfo>)
    {
      // read base dir
      if (!safeExists(base))
        return;
      var entries: Array<String>;
      try { entries = Fs.readdirSync(base); }
      catch (e: Dynamic) {
        mlog('[mods] readdir failed for ' + base + ': ' + e);
        return;
      }

      // each entry = candidate mod dir
      for (name in entries)
        {
          var full = Path.join(base, name);
          var stat: Dynamic;
          try { stat = Fs.statSync(full); }
          catch (e: Dynamic) { continue; }
          if (!stat.isDirectory()) continue;

          // load + validate manifest
          var info = loadManifest(full, source);
          if (info == null) continue;
          if (byID.exists(info.id)) {
            mlog('[mods] duplicate id ' + info.id + ' at ' + full +
              ' (already from ' + byID.get(info.id).rootDir + ')');
            continue;
          }
          byID.set(info.id, info);
          out.push(info);
        }
    }

// scan all mod sources and populates modsList + modsByID.
// sideload first (sideload wins id collisions for dev workflow), workshop after
  static function scanMods()
    {
      modsList = [];
      modsByID = {};
      var exeDir: String;
      try { exeDir = Path.dirname(App.getPath('exe')); }
      catch (e: Dynamic) { exeDir = null; }

      var roots: Array<String> = [];
      if (exeDir != null) roots.push(exeDir);

      mlog('[mods] scan roots: ' + roots.join(', '));
      for (root in roots) {
        for (sub in [{ name: 'mods', source: 'sideload-mods' },
                     { name: 'dev',  source: 'sideload-dev'  }]) {
          var dir = Path.join(root, sub.name);
          var exists = safeExists(dir);
          mlog('[mods]   ' + dir + (exists ? ' (exists)' : ' (skip)'));
          if (!exists) continue;
          scanBaseDir(dir, sub.source, modsList, modsByID);
        }
      }
      scanWorkshopMods(modsList, modsByID);
      mlog('[mods] scan complete: ' + modsList.length + ' mod(s) discovered');
      for (m in modsList)
        mlog('[mods]   - ' + m.id + ' v' + m.version + ' (' + m.source + ') @ ' + m.rootDir);
    }

// best-effort require of steamworks.js native module. failure = log + null.
// expected misses: dep not installed, ABI mismatch with current Electron build.
// caller must check steamworks != null before steamInit()
  static function loadSteamworks()
    {
      try {
        steamworks = js.Syntax.code("require('steamworks.js')");
        mlog('[steam] steamworks.js loaded');
      }
      catch (e: Dynamic) {
        steamworks = null;
        mlog('[steam] steamworks.js require failed: ' + e + ' (workshop disabled)');
      }
    }

// drop steam_appid.txt next to exe so steamworks.init works without
// Steam client launching the binary (per mod-design.md §12 dev-build note)
  static function writeSteamAppidFile()
    {
      try {
        var exeDir = Path.dirname(App.getPath('exe'));
        var p = Path.join(exeDir, 'steam_appid.txt');
        Fs.writeFileSync(p, '' + STEAM_APPID);
      }
      catch (e: Dynamic) {
        mlog('[steam] steam_appid.txt write failed: ' + e);
      }
    }

// enable Steam in-game overlay (Shift+Tab). MUST run pre-ready: appends
// chromium switches (in-process-gpu, disable-direct-composition) consumed
// before GPU process starts. Also installs a 60Hz frame-invalidator on each
// BrowserWindow so the overlay repaints over our canvas-driven UI.
  static function enableSteamOverlay()
    {
      if (steamworks == null) return;
      try {
        steamworks.electronEnableSteamOverlay();
        mlog('[steam] overlay enabled');
      }
      catch (e: Dynamic) {
        mlog('[steam] overlay enable failed: ' + e);
      }
    }

// init steamworks.js with our app id. on failure (no client, sandbox blocked,
// missing module) log + skip workshop. sideload still works.
  static function steamInit()
    {
      if (steamworks == null) return;
      try {
        steamClient = steamworks.init(STEAM_APPID);
        mlog('[steam] init OK (appid=' + STEAM_APPID + ')');
      }
      catch (e: Dynamic) {
        steamClient = null;
        mlog('[steam] init failed: ' + e + ' (workshop disabled)');
      }
    }

// enumerate subscribed workshop items via steamworks.js workshop.* surface.
// not-installed → trigger download + skip this boot; needs-update →
// trigger download + load current; installed → loadManifest on installInfo().folder
  static function scanWorkshopMods(out: Array<ModInfo>, byID: haxe.DynamicAccess<ModInfo>)
    {
      if (steamClient == null) {
        mlog('[mods] workshop: skipped (Steam not ready)');
        return;
      }
      var workshop: Dynamic = steamClient.workshop;
      if (workshop == null) {
        mlog('[mods] workshop: steamworks.js exposes no workshop surface');
        return;
      }

      // getSubscribedItems() → array of published file ids (64-bit ints as strings)
      var ids: Array<Dynamic>;
      try { ids = workshop.getSubscribedItems(); }
      catch (e: Dynamic) {
        mlog('[mods] workshop: getSubscribedItems threw: ' + e);
        return;
      }
      if (ids == null) ids = [];
      mlog('[mods] workshop: ' + ids.length + ' subscribed item(s)');

      // ITEM_STATE_INSTALLED=4, NEEDS_UPDATE=8, DOWNLOADING=16
      for (id in ids)
        {
          var idStr: String = '' + id;
          var state: Int;
          try { state = workshop.state(id); }
          catch (e: Dynamic) {
            mlog('[mods] workshop[' + idStr + ']: state threw: ' + e);
            continue;
          }
          // not installed yet — kick off download, skip this boot
          if ((state & 4) == 0) {
            try { workshop.download(id, false); }
            catch (e: Dynamic) {}
            mlog('[mods] workshop[' + idStr + ']: not installed, download queued (load next launch)');
            continue;
          }

          // stale — load current version, kick update for next boot
          if ((state & 8) != 0) {
            try { workshop.download(id, false); }
            catch (e: Dynamic) {}
            mlog('[mods] workshop[' + idStr + ']: stale, update queued');
          }

          // installed — get install info
          var info: Dynamic;
          try { info = workshop.installInfo(id); }
          catch (e: Dynamic) {
            mlog('[mods] workshop[' + idStr + ']: installInfo threw: ' + e);
            continue;
          }
          if (info == null || info.folder == null) {
            mlog('[mods] workshop[' + idStr + ']: no installInfo, skip');
            continue;
          }

          // load + validate manifest from this folder
          var mod = loadManifest(info.folder, 'workshop');
          if (mod == null) continue;
          mod.workshopID = idStr;
          // id collision: keep workshop entry visible in UI but mark shadowed.
          // sideload wins for load (dev workflow); ModRegistry skips shadowed.
          if (byID.exists(mod.id))
            {
              var by = byID.get(mod.id);
              mod.shadowedBy = by.source;
              mlog('[mods] workshop[' + idStr + ']: id ' + mod.id +
                ' shadowed by ' + by.source + ' @ ' + by.rootDir);
              out.push(mod);
              continue;
            }
          byID.set(mod.id, mod);
          out.push(mod);
        }
    }

// resolve mod:// request to absolute disk path; null on reject (404/403)
  static function resolveModRequest(url: String): String
    {
      // "mod://<id>/<path>"
      if (!StringTools.startsWith(url, 'mod://'))
        return null;
      var rest = url.substr(6);
      var slash = rest.indexOf('/');
      if (slash < 0)
        return null;
      var id = rest.substr(0, slash);
      var subpath = rest.substr(slash + 1);
      if (subpath.length == 0)
        return null;

      // strip query/hash
      var q = subpath.indexOf('?');
      if (q >= 0) subpath = subpath.substr(0, q);
      var h = subpath.indexOf('#');
      if (h >= 0) subpath = subpath.substr(0, h);

      // url-decode
      try { subpath = js.Syntax.code("decodeURIComponent({0})", subpath); }
      catch (e: Dynamic) { return null; }
      if (!modsByID.exists(id))
        return null;
      var root: String = modsByID.get(id).rootDir;
      var resolved: String = Path.resolve(root, subpath);
      var sep: String = js.Syntax.code("require('path').sep");

      // traversal defense — resolved must live under root
      if (resolved != root &&
          !StringTools.startsWith(resolved, root + sep))
        return null;
      return resolved;
    }

// register mod:// scheme privileges (must run BEFORE App.ready)
// corsEnabled:true required for dynamic `import('mod://...')` from file:// origin
  static function registerModSchemePrivileges()
    {
      Protocol.registerSchemesAsPrivileged([
        untyped { scheme: 'mod', privileges: {
          standard: true,
          secure: true,
          supportFetchAPI: true,
          corsEnabled: true,
          stream: true,
        }}
      ]);
    }

// register mod:// protocol handler (after App.ready, after scanMods)
  static function registerModProtocolHandler()
    {
      Protocol.handle('mod', function(req: Dynamic): Dynamic {
        // resolve to disk path
        var abs = resolveModRequest(req.url);
        if (abs == null)
          return js.Syntax.code("new Response('not found', { status: 404 })");

        // determine mime type from extension
        var mime = mimeFor(abs);
        if (mime == null)
          return js.Syntax.code("new Response('unsupported type', { status: 415 })");

        // read file and serve
        var buf: Dynamic;
        try { buf = Fs.readFileSync(abs); }
        catch (e: Dynamic) {
          return js.Syntax.code("new Response('read error', { status: 500 })");
        }
        // no-store: prevents Chromium from serving stale cached responses across
        // renderer reloads (Ctrl+F5). Engine loads assets once into JS heap, so
        // this only affects cold fetches — no per-frame refetch cost
        return js.Syntax.code(
          "new Response({0}, { status: 200, headers: { 'content-type': {1}, 'access-control-allow-origin': '*', 'cache-control': 'no-store' } })",
          buf, mime);
      });
    }

// resolve session log path: log-YYYY-MM-DD.txt (UTC), frozen for session
  static function initLogSession()
    {
      var nowIso: String = js.Syntax.code("new Date().toISOString()");
      var dateStr = nowIso.substr(0, 10); // YYYY-MM-DD
      logPath = writablePath('log-' + dateStr + '.txt');
      try {
        Fs.appendFileSync(logPath,
          '--- session start ' + nowIso +
          ' v' + Version.getVersion() +
          ' ' + Node.process.platform + '\n');
      }
      catch (e: Dynamic) { trace('log start failed: ' + e); }
      // flush pre-ready buffered mlog lines (steamworks load + overlay enable)
      for (line in pendingLog) {
        try { Fs.appendFileSync(logPath, line + '\n'); }
        catch (e: Dynamic) {}
      }
      pendingLog = [];
    }

// write session end marker; idempotent across before-quit + window-all-closed
  static function endLogSession()
    {
      if (sessionEnded || logPath == null) return;
      sessionEnded = true;
      var nowIso: String = js.Syntax.code("new Date().toISOString()");
      try {
        Fs.appendFileSync(logPath, '--- session end ' + nowIso + '\n');
      }
      catch (e: Dynamic) { trace('log end failed: ' + e); }
    }

// register all host:* IPC handlers
  static function registerHostHandlers()
    {
      // boot info: platform
      IpcMain.on('host:boot', function(e) {
        if (Node.process.platform == 'darwin')
          ensureUserDataPath();
        untyped e.returnValue = {
          platform: Node.process.platform,
          isDebug: isDebug,
        };
      });

      // settings
      IpcMain.on('host:settings:read', function(e) {
        untyped e.returnValue = safeReadFile(writablePath('settings.json'));
      });
      IpcMain.on('host:settings:write', function(e: Dynamic, data: Dynamic) {
        if (!isValidString(data, CAP_SETTINGS)) {
          e.returnValue = false;
          return;
        }
        e.returnValue = safeWriteFile(writablePath('settings.json'), cast data);
      });

      // profile
      IpcMain.on('host:profile:read', function(e) {
        untyped e.returnValue = safeReadFile(writablePath('profile.json'));
      });
      IpcMain.on('host:profile:write', function(e: Dynamic, data: Dynamic) {
        if (!isValidString(data, CAP_PROFILE)) {
          e.returnValue = false;
          return;
        }
        e.returnValue = safeWriteFile(writablePath('profile.json'), cast data);
      });
      IpcMain.on('host:profile:exists', function(e) {
        untyped e.returnValue = safeExists(writablePath('profile.json'));
      });

      // save slots
      IpcMain.on('host:save:read', function(e: Dynamic, slotID: Dynamic) {
        if (!isValidSlotID(slotID)) {
          e.returnValue = null;
          return;
        }
        e.returnValue = safeReadFile(writablePath(saveFileName(cast slotID)));
      });
      IpcMain.on('host:save:write', function(e: Dynamic, slotID: Dynamic, data: Dynamic) {
        if (!isValidSlotID(slotID) || !isValidString(data, CAP_SAVE)) {
          e.returnValue = false;
          return;
        }
        e.returnValue = safeWriteFile(
          writablePath(saveFileName(cast slotID)), cast data);
      });
      IpcMain.on('host:save:exists', function(e: Dynamic, slotID: Dynamic) {
        if (!isValidSlotID(slotID)) {
          e.returnValue = false;
          return;
        }
        e.returnValue = safeExists(writablePath(saveFileName(cast slotID)));
      });
      // tiny meta sidecar (slot-list preview) read/write
      IpcMain.on('host:save:readMeta', function(e: Dynamic, slotID: Dynamic) {
        if (!isValidSlotID(slotID)) {
          e.returnValue = null;
          return;
        }
        e.returnValue = safeReadFile(writablePath(saveMetaFileName(cast slotID)));
      });
      IpcMain.on('host:save:writeMeta', function(e: Dynamic, slotID: Dynamic, data: Dynamic) {
        if (!isValidSlotID(slotID) || !isValidString(data, CAP_META)) {
          e.returnValue = false;
          return;
        }
        e.returnValue = safeWriteFile(
          writablePath(saveMetaFileName(cast slotID)), cast data);
      });
      // delete slot: removes both the save and its meta sidecar
      IpcMain.on('host:save:delete', function(e: Dynamic, slotID: Dynamic) {
        if (!isValidSlotID(slotID)) {
          e.returnValue = false;
          return;
        }
        var ok = safeDelete(writablePath(saveFileName(cast slotID)));
        safeDelete(writablePath(saveMetaFileName(cast slotID)));
        e.returnValue = ok;
      });

      // console history
      IpcMain.on('host:console:read', function(e) {
        untyped e.returnValue = safeReadFile(writablePath('history.json'));
      });
      IpcMain.on('host:console:write', function(e: Dynamic, data: Dynamic) {
        if (!isValidString(data, CAP_HISTORY)) {
          e.returnValue = false;
          return;
        }
        e.returnValue = safeWriteFile(writablePath('history.json'), cast data);
      });
      IpcMain.on('host:console:exists', function(e) {
        untyped e.returnValue = safeExists(writablePath('history.json'));
      });

      // exception log append (target file resolved once at App.ready)
      IpcMain.on('host:log:append', function(e: Dynamic, line: Dynamic) {
        if (!isValidString(line, CAP_LOGLINE) || logPath == null) {
          e.returnValue = false;
          return;
        }
        try {
          Fs.appendFileSync(logPath, cast line);
          e.returnValue = true;
        }
        catch (err: Dynamic)
          {
            e.returnValue = false;
          }
      });

      // mods list: returns cached scan from App.ready. Use host:mods:rescan
      // to refresh from disk (e.g. dev workflow with added/removed folders).
      IpcMain.on('host:mods:list', function(e) {
        untyped e.returnValue = modsList;
      });

      // explicit rescan: re-enumerates sideload + workshop, returns fresh list
      IpcMain.on('host:mods:rescan', function(e) {
        scanMods();
        untyped e.returnValue = modsList;
      });

      // open sideload mods folder in OS file manager.
      // creates <exeDir>/mods if missing so opening always succeeds.
      IpcMain.on('host:mods:openFolder', function(e) {
        try
          {
            var exeDir = Path.dirname(App.getPath('exe'));
            var dir = Path.join(exeDir, 'mods');
            if (!safeExists(dir))
              Fs.mkdirSync(dir);
            Shell.openPath(dir);
            untyped e.returnValue = true;
          }
        catch (err: Dynamic)
          {
            mlog('[mods] openFolder failed: ' + err);
            untyped e.returnValue = false;
          }
      });

      // open external url; only steam:// and https://steamcommunity.com/
      // accepted (used by Mods UI for workshop pages + browse-workshop).
      IpcMain.on('host:shell:openExternal', function(e, url: Dynamic) {
        if (!Std.isOfType(url, String))
          {
            untyped e.returnValue = false;
            return;
          }
        var s: String = cast url;
        var ok = StringTools.startsWith(s, 'steam://') ||
                 StringTools.startsWith(s, 'https://steamcommunity.com/');
        if (!ok)
          {
            untyped e.returnValue = false;
            return;
          }
        try
          {
            Shell.openExternal(s);
            untyped e.returnValue = true;
          }
        catch (err: Dynamic)
          {
            mlog('[shell] openExternal failed: ' + err);
            untyped e.returnValue = false;
          }
      });

      // sound asset listing
      IpcMain.on('host:assets:listSounds', function(e) {
        try
          {
            untyped e.returnValue = Fs.readdirSync(soundDir());
          }
        catch (err: Dynamic)
          {
            untyped e.returnValue = [];
          }
      });

      // window control
      IpcMain.handle('host:quit', function(e) {
        App.quit();
      });
      IpcMain.handle('host:fullscreen:on', function(e) {
        win.fullScreen = true;
      });
      IpcMain.handle('host:fullscreen:off', function(e) {
        win.fullScreen = false;
      });

      // debug-only writes: handlers always registered, gated at runtime.
      // when sentinel (.debug) absent, all calls refuse with false
      IpcMain.on('host:debug:roads', function(e: Dynamic, text: Dynamic) {
        if (!isDebug ||
            !isValidString(text, CAP_DEBUG_TEXT)) {
          e.returnValue = false;
          return;
        }
        e.returnValue = safeWriteFile(
          Path.join(debugDir(), 'region_roads.txt'), cast text);
      });
      IpcMain.on('host:debug:buildings', function(e: Dynamic, text: Dynamic) {
        if (!isDebug ||
            !isValidString(text, CAP_DEBUG_TEXT)) {
          e.returnValue = false;
          return;
        }
        e.returnValue = safeWriteFile(
          Path.join(debugDir(), 'region_buildings.txt'), cast text);
      });
      IpcMain.on('host:debug:image', function(e: Dynamic, name: Dynamic, base64: Dynamic) {
        if (!isDebug ||
            !isValidBasename(name) ||
            !isValidString(base64, CAP_IMAGE_B64)) {
          e.returnValue = false;
          return;
        }
        try {
          var buf = js.Syntax.code("Buffer.from({0}, 'base64')", base64);
          Fs.writeFileSync(Path.join(debugDir(), cast name), buf);
          e.returnValue = true;
        }
        catch (err: Dynamic)
          {
            e.returnValue = false;
          }
      });
    }

  static function main()
    {
      // force sandbox on all renderers (mod hardening). the scary opt-out
      // --dangerous-disable-mod-sandbox is the only user-facing knob: when set
      // we add Chromium's builtin --no-sandbox ourselves and skip enableSandbox.
      // (calling enableSandbox() alongside --no-sandbox contradicts the flag and
      // aborts Chromium sandbox init at startup → silent exit on Windows)
      if (App.commandLine.hasSwitch('dangerous-disable-mod-sandbox'))
        App.commandLine.appendSwitch('no-sandbox');
      else
        App.enableSandbox();
      registerModSchemePrivileges();
      registerHostHandlers();
      // steamworks.js must load + overlay switches must apply before App.ready
      // (chromium consumes command-line switches before GPU process starts)
      loadSteamworks();
      enableSteamOverlay();

      App.on(ready, function(e)
        {
          // resolve runtime debug flag: present iff a .debug sentinel file
          // sits in cwd (game install dir). cached for entire session
          try {
            isDebug = Fs.existsSync(Path.join(Node.process.cwd(), '.debug'));
          }
          catch (err: Dynamic) { isDebug = false; }

          initLogSession();
          writeSteamAppidFile();
          steamInit();
          scanMods();
          registerModProtocolHandler();

          // load config
          var obj: { fullscreen: String } = null;
          try {
            var s = Fs.readFileSync(getSettingsPath(), 'utf8');
            obj = Json.parse(s);
          }
          catch (e: Dynamic)
            {
              trace(e);
            }
          var isFullscreen = false;
          if (obj != null)
            {
              isFullscreen = (obj.fullscreen != null && obj.fullscreen != '0');
            }

          // create main window
//          var isClassic = App.commandLine.hasSwitch('classic');
          win = new BrowserWindow({
            icon: __dirname + '/favicon.png',
            width: 1056,
            height: 685,
            minWidth: 600,
            minHeight: 400,
            fullscreen: isFullscreen,
            webPreferences: {
              preload: Path.join(__dirname, 'preload.js'),
              nodeIntegration: false,
              contextIsolation: true,
              sandbox: true,
              webSecurity: true,
              backgroundThrottling: false,
            }
          });
          // no app menu in any build: removes the default Ctrl+W "close window"
          // accelerator (Ctrl+W is repurposed as console word-delete). the menu
          // also carried F11 fullscreen + dev shortcuts, so rebind them here:
          // F11 in all builds, devtools / reload only in debug
          win.setMenu(null);
          untyped win.webContents.on('before-input-event', function(e, input) {
            if (input.type != 'keyDown')
              return;
            var k = ('' + input.key).toLowerCase();
            if (k == 'f11')
              win.fullScreen = !win.fullScreen;
            else if (isDebug &&
                (k == 'f12' || (input.control && input.shift && k == 'i')))
              win.webContents.toggleDevTools();
            else if (isDebug && input.control && k == 'r')
              win.webContents.reload();
          });

          // block all in-window navigation
          win.webContents.on('will-navigate', function(e, url) {
            untyped e.preventDefault();
          });
          // deny window.open / target=_blank
          untyped win.webContents.setWindowOpenHandler(function(details) {
            return { action: 'deny' };
          });

          // push OS focus changes to the renderer (window blur/visibilitychange
          // don't fire reliably here) so the menu can pause its decorative anims
          untyped win.on('focus', function() win.webContents.send('host:focus', true));
          untyped win.on('blur', function() win.webContents.send('host:focus', false));

          win.loadFile('app.html');
          if (isDebug)
            win.webContents.openDevTools();
        });

      App.on(window_all_closed, function(e) {
          endLogSession();
          if (Node.process.platform != 'darwin')
            App.quit();
      });

      untyped App.on('before-quit', function(e) {
          endLogSession();
      });

      App.commandLine.appendSwitch('in-process-gpu');
      App.commandLine.appendSwitch('disable-direct-composition');
      // keep the compositor rendering when the window is occluded/backgrounded so
      // CDP Page.captureScreenshot works while the game isn't foreground (dev tooling)
      App.commandLine.appendSwitch('disable-backgrounding-occluded-windows');
      App.commandLine.appendSwitch('disable-renderer-backgrounding');
      App.commandLine.appendSwitch('disable-background-timer-throttling');
    }
}
