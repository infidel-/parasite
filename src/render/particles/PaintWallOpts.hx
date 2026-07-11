package render.particles;

import three.Three;

// options for Sprites.paintWall(): a quad standing on a wall face (bullet holes, wall blood)
typedef PaintWallOpts = {
  var x:Float;                // world position (nudged proud of the face by the caller)
  var y:Float;
  var z:Float;
  var tex:Texture;            // decal texture (null = not loaded yet, no-op)
  var op:Float;               // opacity
  var scale:Float;            // uniform scale of SIZE
  var faceRotY:Float;         // outward normal yaw (see Geom.faceRotY)
  var roll:Float;             // in-plane spin about the face normal
  @:optional var rough:Float; // material roughness (wet sheen < 1), default 1.0
  @:optional var metal:Float; // material metalness, default 0
}
