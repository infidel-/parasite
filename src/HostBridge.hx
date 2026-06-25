// renderer-side bridge to main process via window.host (set by preload.js)
// thin typed wrapper around the contextBridge surface

import mods.ModInfo;

#if electron
class HostBridge
{
  static inline function h(): Dynamic return js.Syntax.code("window.host");

// platform string: 'win32' | 'darwin' | 'linux'
  public static var platform(get, never): String;
  static function get_platform(): String return h().platform;

// runtime debug flag: true if main found a .debug sentinel file in cwd at boot
  public static var isDebug(get, never): Bool;
  static function get_isDebug(): Bool return h().isDebug;

// settings.json read/write (JSON string)
  public static function settingsRead(): String return h().settings.read();
  public static function settingsWrite(data: String): Void h().settings.write(data);

// profile.json read/write/exists
  public static function profileRead(): String return h().profile.read();
  public static function profileWrite(data: String): Void h().profile.write(data);
  public static function profileExists(): Bool return h().profile.exists();

// savegame slot read/write/exists (slotID is Int, file name is save<NN>.json)
  public static function saveRead(slotID: Int): String return h().save.read(slotID);
  public static function saveWrite(slotID: Int, data: String): Void h().save.write(slotID, data);
  public static function saveExists(slotID: Int): Bool return h().save.exists(slotID);

// console history.json read/write/exists
  public static function consoleHistoryRead(): String return h().consoleHistory.read();
  public static function consoleHistoryWrite(data: String): Void h().consoleHistory.write(data);
  public static function consoleHistoryExists(): Bool return h().consoleHistory.exists();

// exception log append (writes one line to session log-YYYY-MM-DD.txt)
  public static function logAppend(line: String): Void h().log.append(line);

// sound asset directory listing (file names only)
  public static function listSounds(): Array<String> return h().assets.listSounds();

// mod scan list (manifests resolved + validated in main)
  public static function modsList(): Array<ModInfo> return h().mods.list();
  public static function modsRescan(): Array<ModInfo> return h().mods.rescan();
  public static function modsOpenFolder(): Bool return h().mods.openFolder();

// open url in external browser / steam client (whitelisted schemes)
  public static function shellOpenExternal(url: String): Bool return h().shell.openExternal(url);

// window control
  public static function quit(): Void h().quit();
  public static function setFullscreen(on: Bool): Void h().setFullscreen(on);

// register a callback fired on OS window focus/blur (focused: Bool)
  public static function onFocusChange(cb: Bool -> Void): Void h().onFocusChange(cb);

// debug-only writes — main refuses with false when sentinel (.debug) is absent
  public static function debugWriteRegionRoads(text: String): Void h().debug.writeRegionRoads(text);
  public static function debugWriteRegionBuildings(text: String): Void h().debug.writeRegionBuildings(text);
  public static function debugWriteImage(name: String, base64: String): Void h().debug.writeImage(name, base64);
}
#end
