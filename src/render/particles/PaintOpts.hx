package render.particles;

import three.Three;

// options for Sprites.paint(): required position/texture/opacity/scale plus named optional
// overrides, replacing the old 16-positional-arg signature
typedef PaintOpts = {
  var x:Float;                       // world position
  var y:Float;
  var z:Float;
  var tex:CanvasTexture;             // sprite texture (null = atlas not decoded yet, no-op)
  var op:Float;                      // opacity
  var scale:Float;                   // uniform scale of SIZE
  @:optional var flat:Bool;          // lie flat on the ground as a decal (default false)
  @:optional var yaw:Float;          // ground rotation (flat) / in-plane roll (upright), default 0
  @:optional var order:Float;        // renderOrder (ORD_*, fractional allowed to break ties), default 0
  @:optional var emissive:Int;       // self-glow color, default 0 = no glow
  @:optional var emissiveInt:Float;  // self-glow intensity, default 0
  @:optional var depthTest:Bool;     // false = always-on-top UI, default true
  @:optional var depthFunc:Dynamic;  // three.js depth-func const (untyped extern), default null
  @:optional var faceX:Float;        // horizontal facing mirror in [-1..1], default 1.0
  @:optional var rough:Float;        // material roughness (wet sheen < 1), default 1.0
  @:optional var metal:Float;        // material metalness, default 0
  @:optional var shadow:Bool;        // sample the moon/lamp shadow maps, default true (false = UI overlay)
}
