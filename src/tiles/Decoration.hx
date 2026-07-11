// tile decoration metadata for layer-based rendering

package tiles;

typedef Decoration = {
  // which decoration image are we using
  var layerID: Int;
  @:optional var icon: _Icon;
  @:optional var dx: Int;
  @:optional var dy: Int;
  @:optional var scale: Float;
  @:optional var angle: Float;
  @:optional var tag: String;
  // wall decals (bullet holes): the face dir 0-3 the decal stands on (absent = flat ground
  // decal), and its world Y up the wall. angle doubles as the in-plane roll
  @:optional var face: Int;
  @:optional var height: Float;
  // bullet hole on a metal-warehouse wall -> use the steel-dent texture set (absent/false = masonry)
  @:optional var metal: Bool;
}
