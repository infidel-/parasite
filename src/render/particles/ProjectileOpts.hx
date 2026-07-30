package render.particles;

import three.Three;

// options for Actors.projectile() / the Projectile3D ctor: one thrown blob's flight, sprite and
// impact beat, replacing the old 10-positional-arg signature. every field is required — there is
// one caller (render.choreo.Projectile) and it reads all of them off a RenderConfig.PROJECTILE kind
typedef ProjectileOpts = {
  var src:Vector3;            // source world pos (y = flight height)
  var dst:Vector3;            // impact world pos (y ignored — the flight holds src's height)
  var col:Int;                // entities-atlas column of the blob sprite
  var row:Int;                // entities-atlas row of the blob sprite
  var glow:Int;               // emissive tint on the blob (0 = none; acid/slime goop)
  var scale:Float;            // main blob scale (of a billboard)
  var drips:Int;              // trailing drip blobs
  var travelMs:Float;         // full flight time
  var arc:Float;              // sine lob peak above the flight line (cells); 0 = flat
  var onImpact:Void->Void;    // impact beat (splat burst + sound); may be null
}
