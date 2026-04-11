// electron file-system paths

#if electron
import electron.renderer.IpcRenderer;
import js.Node;
import js.node.Path;
#end

class ElectronPaths
{
  static var writableBasePath: String = null;
  static var assetBasePath: String = null;

// get one writable file path under electron user data
  public static function getWritablePath(path: String): String
    {
#if electron
      if (Node.process.platform != 'darwin')
        return path;
      init();
      return Path.join(writableBasePath, path);
#else
      return path;
#end
    }

// get one bundled asset path under electron app directory
  public static function getAssetPath(path: String): String
    {
#if electron
      if (Node.process.platform != 'darwin')
        return path;
      init();
      return Path.join(assetBasePath, path);
#else
      return path;
#end
    }

// cache renderer-visible electron paths
  static function init()
    {
#if electron
      if (writableBasePath != null)
        return;
      writableBasePath = cast IpcRenderer.sendSync('get-user-data-path');
      assetBasePath = cast IpcRenderer.sendSync('get-app-path');
#end
    }
}
