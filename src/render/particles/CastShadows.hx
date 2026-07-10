package render.particles;

import three.Three;

// a light that casts fake shadows: ground position + the projection knobs. barrels and lamps both
// build these, so the projector below stays light-agnostic (no barrel/lamp specifics leak in)
typedef ShadowLight = {
  var x:Float;       // light world x
  var z:Float;       // light world z
  var range:Float;   // world radius; an actor beyond this casts no shadow from this light
  var lenMul:Float;  // shadow length multiplier (low barrels long, overhead lamps short)
  var op:Float;      // base per-shadow opacity
  var fade:Float;    // outer fraction of range over which the shadow eases to 0 (no pop on enter/leave)
  var flicker:Float; // 0..1 pulse (barrels breathe with the flame; steady lamps pass 1)
};

// shared fake-shadow projector: lays a black soft-edged copy of an actor's sprite on the ground,
// stretched away from each nearby light. generalized from the barrel-only Actors.actorShadow so
// street lamps reuse the exact same math. no shadow maps — just oriented, darkened alpha quads
class CastShadows {

// project one actor's silhouette (gs, at feet ax,az on floorY, faded by actorOp) away from the
// nearest `max` lights within range. per light: dir = away from the light, length grows with
// distance * lenMul, opacity fades at the rim + with distance + the light's flicker
  public static function project(sprites:Sprites, gs:GroundSprite, ax:Float, az:Float, floorY:Float,
      actorOp:Float, lights:Array<ShadowLight>, max:Int):Void
    {
      if (gs == null)
        return;
      var widWorld = gs.fw * Sprites.SIZE;
      var fh = gs.fh * Sprites.SIZE;
      // nearest lights within their own range by WORLD distance (smooth), capped to max. world
      // distance (not cell) so the edge fade below eases continuously as the actor crosses the radius
      var near:Array<{ l:ShadowLight, d:Float }> = [];
      for (l in lights)
        {
          var dx = ax - l.x;
          var dz = az - l.z;
          var d = Math.sqrt(dx * dx + dz * dz);
          if (d < l.range)
            near.push({ l: l, d: d });
        }
      near.sort(function(p, q)
        {
          return p.d < q.d ? -1 : (p.d > q.d ? 1 : 0);
        });
      var n = near.length < max ? near.length : max;
      for (i in 0...n)
        {
          var l = near[i].l;
          var dh = near[i].d;
          if (dh < 0.001)
            continue;
          var dx = (ax - l.x) / dh;
          var dz = (az - l.z) / dh;
          var len = fh * l.lenMul * (0.5 + dh / l.range);
          // smooth edge fade: 1 well inside the radius, easing to 0 at its rim over the outer
          // `fade` fraction, so the shadow fades in/out as the actor walks in/out (no pop)
          var edge = (l.range - dh) / (l.range * l.fade);
          if (edge > 1)
            edge = 1;
          // fade with distance from the light: darker close to it, more transparent far off
          var distFade = 1 - dh / l.range;
          var op = l.op * actorOp * edge * distFade * (0.7 + 0.3 * l.flicker);
          sprites.paintShadow({
            feetX: ax,
            floorY: floorY,
            feetZ: az,
            gs: gs,
            dirX: dx,
            dirZ: dz,
            len: len,
            wid: widWorld,
            op: op,
            order: Sprites.ORD_SHADOW,
          });
        }
    }
}
