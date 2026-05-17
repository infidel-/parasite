// main electron entry-point

import haxe.Json;
import js.Node;
import js.Node.__dirname;
import js.node.Fs;
import js.node.Path;
import electron.main.App;
import electron.main.BrowserWindow;
import electron.main.IpcMain;

class MainElectron
{
  static var win: BrowserWindow;

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

      // exception log append
      IpcMain.on('host:log:append', function(e: Dynamic, line: Dynamic) {
        if (!isValidString(line, CAP_LOGLINE)) {
          e.returnValue = false;
          return;
        }
        try {
          Fs.appendFileSync(writablePath('exceptions.txt'), cast line);
          e.returnValue = true;
        }
        catch (err: Dynamic)
          {
            e.returnValue = false;
          }
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
      registerHostHandlers();

      App.on(ready, function(e)
        {
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
          if (Node.process.platform != 'darwin')
            App.quit();
      });

      App.commandLine.appendSwitch('in-process-gpu');
      App.commandLine.appendSwitch('disable-direct-composition');
    }
}
