package tiles;

// weighted floor decoration metadata used by themed generators
typedef _FloorDecorMeta = {
  var icon: _Icon;
  var motifs: Array<String>;
  var roles: Array<String>;
  @:optional var light: _AtmosphereLightMeta;
  var baseWeight: Int;
}
