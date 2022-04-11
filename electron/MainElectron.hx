// main electron entry-point

import haxe.Json;
import js.Node;
import js.Node.__dirname;
import js.node.Fs;
import electron.main.App;
import electron.main.BrowserWindow;
import electron.main.IpcMain;

class MainElectron
{
  static var win: BrowserWindow;
  static function main()
    {
      App.on(ready, function(e)
        {
          // load config
          var obj: { fullscreen: String } = null;
          try {
            var s = Fs.readFileSync('settings.json', 'utf8');
            obj = Json.parse(s);
          }
          catch (e: Dynamic)
            {
              trace(e);
            }
          var isFullscreen = (obj.fullscreen != null && obj.fullscreen != '0');

          // create main window
//          var isClassic = App.commandLine.hasSwitch('classic');
          win = new BrowserWindow({
            icon: __dirname + '/favicon.png',
            width: 1056,
            height: 685,
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
          win.on( closed, function() {
              win = null;
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

      IpcMain.handle('quit', function(e) {
        App.quit();
      });
      IpcMain.handle('fullscreen0', function(e) {
        win.fullScreen = false;
      });
      IpcMain.handle('fullscreen1', function(e) {
        win.fullScreen = true;
      });
    }
}
