package render.particles;

// options for Sprites.paintGround(): a content-cropped sprite laid flat on the ground at its
// true pixel footprint
typedef PaintGroundOpts = {
  var x:Float;              // world position
  var y:Float;
  var z:Float;
  var gs:GroundSprite;      // content-trimmed sprite (null = atlas not decoded yet, no-op)
  var op:Float;             // opacity
  var scale:Float;          // multiplies the sprite's true footprint
  var yaw:Float;            // in-plane ground rotation
  @:optional var order:Int; // renderOrder (ORD_*), default 0
}
