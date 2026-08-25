package render.decals;

import citygen.CityConfig;
import render.RenderConfig;
import render.particles.Sprites;
import render.world.WorldCtx;

// seed-derived street debris scatter (render-only, never persisted): content-cropped flat ground
// quads, radius-faded per cell around the player like the blood decals. rebuilt per city show
class Debris {
  var d:Decals;                                          // coordinator back-ref (batch, sprites, radiusOp)
  var list:Array<render.world.Debris.DebrisSpot> = null; // current scatter (render-only)

  public function new(d:Decals)
    {
      this.d = d;
    }

// set the seed-derived debris scatter for the current city
  public function set(list:Array<render.world.Debris.DebrisSpot>):Void
    {
      this.list = list;
    }

// paint the debris as content-cropped flat ground quads, fog-gated per cell like the blood decals.
// instanced: one draw call per debris texture instead of one quad each.
//
// the art is the ONLY alpha-capped block in entities64: rows 41-47 (Const.STREET_DEBRIS_*) peak at
// alpha 127 where every other row of the 12x48 atlas peaks at 255, so litter draws at ~43% opacity
// and can never read as solid whatever RenderConfig.DECAL.debrisMul does. Worth knowing before
// measuring it — scan those rows at the usual alpha > 128 and they come back COMPLETELY EMPTY,
// because nothing in them clears the threshold
  public function draw():Void
    {
      if (list == null)
        return;
      var atlas = d.sprites.atlasTex('entities', false, RenderConfig.DECAL.debrisMul);
      if (atlas == null)
        return;
      for (s in list)
        {
          var r = d.sprites.contentRect('entities', s.ix, s.iy, false);
          if (r == null)
            continue;
          var w = CityConfig.cellToWorld(s.col + s.dx, s.row + s.dy);
          var op = d.radiusOp(w.x, w.z);
          if (op <= 0.001)
            continue;
          // geometry is a unit quad, so bake the content footprint (SIZE * fw/fh) into the size.
          // height off floorYAt and not floorY: the quad sits at s.col + s.dx, up to a quarter cell
          // off centre, and floorY answers about the CENTRE — see RenderConfig.DECAL.groundLift for
          // what that cost on the highway
          d.batch.add(atlas, r, w.x, WorldCtx.floorYAt(w.x, w.z) + RenderConfig.DECAL.groundLift, w.z,
            Sprites.SIZE * r.fw * s.scale, Sprites.SIZE * r.fh * s.scale, s.angle, op, 1.0, 0.0);
        }
    }
}
