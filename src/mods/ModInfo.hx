// mod manifest as returned from main process scan
package mods;

typedef ModInfo = {
  // reverse-DNS-ish identifier; uniqueness enforced at scan
  var id: String;
  // human-readable display name; defaults to id if missing
  var name: String;
  // author string; empty if missing
  var author: String;
  // semver-ish string (digits/letters/dots/hyphens)
  var version: String;
  // must equal Const.MOD_API_VERSION exactly (§3.1)
  var modApiVersion: Int;
  // entry script filename, basename only (no path separators)
  var entry: String;
  // absolute filesystem path to mod dir; resolved in main process
  var rootDir: String;
  // origin: "sideload-mods" | "sideload-dev" | "workshop"
  var source: String;
  // optional: skip mod if engine version < this
  @:optional var minGameVersion: String;
  // optional: required mods (id + version constraint); missing = skip
  @:optional var dependencies: Array<{ id: String, version: String }>;
  // optional: ordering hint — this mod loads after listed ids
  @:optional var loadAfter: Array<String>;
  // optional: ordering hint — this mod loads before listed ids
  @:optional var loadBefore: Array<String>;
}
