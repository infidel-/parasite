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
import mods.ModInfo;

class MainElectron
{
  static var win: BrowserWindow;
  // resolved once at App.ready; all session log writes target this file
  static var logPath: String = null;
  static var sessionEnded: Bool = false;
  // populated by scanMods() at App.ready; served to renderer via host:mods:list
  // also indexed by id for mod:// protocol handler resolution
  static var modsList: Array<ModInfo> = [];
  static var modsByID: haxe.DynamicAccess<ModInfo> = {};

  // size caps (bytes)
  static inline var CAP_SETTINGS = 256 * 1024;
  static inline var CAP_PROFILE  = 1024 * 1024;
  static inline var CAP_HISTORY  = 256 * 1024;
  static inline var CAP_SAVE     = 32 * 1024 * 1024;
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

// file-only log (no stdout); silently no-ops if logPath not yet resolved
  static function mlog(line: String)
    {
      if (logPath == null) return;
      try { Fs.appendFileSync(logPath, line + '\n'); }
      catch (e: Dynamic) {}
    }

// validate manifest mod id: lowercase [a-z0-9_], optional dot segments, 4-80 chars
  static function isValidModID(s: Dynamic): Bool
    {
      if (!Std.isOfType(s, String))
        return false;
      var str: String = cast s;
      if (str.length < 4 || str.length > 80)
        return false;
      var re = ~/^[a-z0-9_]+(\.[a-z0-9_]+)*$/;
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
      if (StringTools.endsWith(lower, '.json'))
        return 'application/json';
      if (StringTools.endsWith(lower, '.png'))
        return 'image/png';
      if (StringTools.endsWith(lower, '.jpg') ||
          StringTools.endsWith(lower, '.jpeg'))
        return 'image/jpeg';
      if (StringTools.endsWith(lower, '.mp3'))
        return 'audio/mpeg';
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
      var info: ModInfo = {
        id: m.id,
        name: (m.name != null ? m.name : m.id),
        author: (m.author != null ? m.author : ''),
        version: m.version,
        modApiVersion: m.modApiVersion,
        entry: m.entry,
        rootDir: rootDir,
        source: source,
        minGameVersion: m.minGameVersion,
        dependencies: m.dependencies,
        loadAfter: m.loadAfter,
        loadBefore: m.loadBefore,
        assets: walkAssets(rootDir),
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

// scan all mod sources and populates modsList + modsByID
// dirs: <exeDir>/mods, <exeDir>/dev (sideload)
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
      mlog('[mods] scan complete: ' + modsList.length + ' mod(s) discovered');
      for (m in modsList)
        mlog('[mods]   - ' + m.id + ' v' + m.version + ' (' + m.source + ') @ ' + m.rootDir);
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

      // mods list (sideload merge); rescan on every call so renderer reload
      // picks up added/removed mod folders without app restart
      IpcMain.on('host:mods:list', function(e) {
        scanMods();
        untyped e.returnValue = modsList;
      });

      // sound asset listing
      IpcMain.on('host:assets:listSounds', function(e) {
        try {
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

#if mydebug
      // debug-only writes (mydebug builds only)
      IpcMain.on('host:debug:roads', function(e: Dynamic, text: Dynamic) {
        if (!isValidString(text, CAP_DEBUG_TEXT)) {
          e.returnValue = false;
          return;
        }
        e.returnValue = safeWriteFile(
          Path.join(debugDir(), 'region_roads.txt'), cast text);
      });
      IpcMain.on('host:debug:buildings', function(e: Dynamic, text: Dynamic) {
        if (!isValidString(text, CAP_DEBUG_TEXT)) {
          e.returnValue = false;
          return;
        }
        e.returnValue = safeWriteFile(
          Path.join(debugDir(), 'region_buildings.txt'), cast text);
      });
      IpcMain.on('host:debug:image', function(e: Dynamic, name: Dynamic, base64: Dynamic) {
        if (!isValidBasename(name) || !isValidString(base64, CAP_IMAGE_B64)) {
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
#end
    }

  static function main()
    {
      App.enableSandbox();
      registerModSchemePrivileges();
      registerHostHandlers();

      App.on(ready, function(e)
        {
          initLogSession();
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
            }
          });
#if !mydebug
          win.setMenu(null);
#end

          // block all in-window navigation
          win.webContents.on('will-navigate', function(e, url) {
            untyped e.preventDefault();
          });
          // deny window.open / target=_blank
          untyped win.webContents.setWindowOpenHandler(function(details) {
            return { action: 'deny' };
          });

          win.loadFile('app.html');
#if mydebug
          win.webContents.openDevTools();
#end
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
    }
}
