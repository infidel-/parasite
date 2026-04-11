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

// ensure electron user data directory exists
  static function ensureUserDataPath()
    {
      var path = App.getPath('userData');
      if (!Fs.existsSync(path))
        Fs.mkdirSync(path);
    }

// get settings file path from electron user data
  static function getSettingsPath(): String
    {
      if (Node.process.platform != 'darwin')
        return 'settings.json';
      ensureUserDataPath();
      return Path.join(App.getPath('userData'), 'settings.json');
    }

  static function main()
    {
      IpcMain.on('get-user-data-path', function(e) {
        if (Node.process.platform == 'darwin')
          ensureUserDataPath();
        untyped e.returnValue = App.getPath('userData');
      });
      IpcMain.on('get-app-path', function(e) {
        untyped e.returnValue = App.getAppPath();
      });
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
              nodeIntegration: true,
              contextIsolation: false,
//              enableRemoteModule: true,
            }
          });
#if !mydebug
          win.setMenu(null);
#end
/*
          win.on(closed, function(e) {
              win = null;
          });*/
          win.loadFile('app.html');
#if mydebug
          win.webContents.openDevTools();
#end
        });

      App.on(window_all_closed, function(e) {
          if (Node.process.platform != 'darwin')
            App.quit();
      });

      IpcMain.handle('quit', function(e) {
        App.quit();
      });
      IpcMain.handle('fullscreen0', function(e) {
        win.fullScreen = false;
      });
      IpcMain.handle('fullscreen1', function(e) {
        win.fullScreen = true;
      });
      App.commandLine.appendSwitch('in-process-gpu');
      App.commandLine.appendSwitch('disable-direct-composition');
    }
}
