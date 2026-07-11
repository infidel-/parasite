package render.particles;

// options for Sprites.paintShadow(): a fake cast shadow rooted at the actor's feet, stretched
// along the away-from-light direction on the ground
typedef PaintShadowOpts = {
  var feetX:Float;          // actor feet world x (shadow root)
  var floorY:Float;         // ground world y
  var feetZ:Float;          // actor feet world z (shadow root)
  var gs:GroundSprite;      // black soft-edged silhouette (null = atlas not decoded yet, no-op)
  var dirX:Float;           // away-from-light unit direction x
  var dirZ:Float;           // away-from-light unit direction z
  var len:Float;            // shadow length, world units
  var wid:Float;            // shadow width, world units
  var op:Float;             // opacity
  @:optional var order:Int; // renderOrder (ORD_*), default 0
}
