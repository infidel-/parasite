// per-mod runtime surface — what entry.init(parasite) receives
// mirrors engine src/mods/ModRuntime.hx
package mods;

typedef ModRuntime = {
  // owning mod's id (matches its manifest)
  var modID: String;
  // owning mod's version (matches its manifest)
  var modVersion: String;
  // engine Const.MOD_API_VERSION at load time
  var modApiVersion: Int;
  // live engine game instance (Game.inst) — untyped pending Game extern
  var game: Dynamic;
  // window.host IPC bridge; untyped contextBridge surface from preload
  var host: Dynamic;
  // $hxClasses registry: raw JS map of class-name -> Haxe class ref
  // also reachable as window.parasiteHx for @:native extern targets
  var hxClasses: Dynamic;
  // engine version string
  var version: String;
  // per-mod content registration facade (registerItem, etc.)
  var api: ModContentApi;
}
