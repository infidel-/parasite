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
}
