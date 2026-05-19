typedef _SaveGame = {
  var version: Int;
  var game: Dynamic;
  // snapshot of enabled mods at save time; loader diffs against
  // currently-enabled set and warns on missing/added/version-mismatch entries.
  @:optional var _activeMods: Array<{ id: String, version: String }>;
}
