package render.particles;

import three.Three;

// options for Sprites.paintTopple(): the death topple — a feet-planted sprite tipping from its
// live upright rest pose (fall 0) to flat on the ground (fall 1), spun about the vertical
typedef PaintToppleOpts = {
  var x:Float;           // feet-planted world position (y = floorY)
  var y:Float;
  var z:Float;
  var tex:CanvasTexture; // sprite texture (null = atlas not decoded yet, no-op)
  var op:Float;          // opacity
  var scale:Float;       // uniform scale of SIZE
  var spinY:Float;       // world-vertical spin (radians)
  var fall:Float;        // topple progress 0 (upright) .. 1 (flat on the ground)
}
