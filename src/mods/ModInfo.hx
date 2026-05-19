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
  // must equal Const.MOD_API_VERSION exactly
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
  // relative asset paths under <rootDir>/assets/ (forward-slash, no leading slash).
  // populated by main-process scan via recursive walk; empty array if no assets/ dir.
  // engine merges into AssetPath at load time for asset override
  var assets: Array<String>;
  // workshop-only: PublishedFileId of the workshop item (decimal string).
  // null for sideload mods. used by Mods UI for "open on workshop" link.
  @:optional var workshopID: String;
  // if set, this mod's id collides with another (already-loaded) mod from the
  // listed source. shadowed mods are kept in registry.all for UI visibility
  // but skipped from candidates (not loaded). e.g. workshop entry shadowed
  // by a sideload-dev folder with the same id.
  @:optional var shadowedBy: String;
}
