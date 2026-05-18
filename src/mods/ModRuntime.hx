// per-mod runtime surface — what entry.init(parasite) receives
// also assigned to window.parasite for direct access from mod code
package mods;

import game.Game;

typedef ModRuntime = {
  // owning mod's id (matches its manifest)
  var modID: String;
  // owning mod's version (matches its manifest)
  var modVersion: String;
  // engine Const.MOD_API_VERSION at load time
  var modApiVersion: Int;
  // live engine game instance (Game.inst)
  var game: Game;
  // window.host IPC bridge; untyped contextBridge surface from preload
  var host: Dynamic;
  // $hxClasses registry: raw JS map of class-name -> Haxe class ref
  var hxClasses: Dynamic;
  // engine version string (Version.getVersion())
  var version: String;
  // per-mod content registration facade (registerItem, etc.)
  var api: ModContentApi;
}
