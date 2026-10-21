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
  public function draw():Void
    {
      // an empty scatter must not build the atlas: every kind hands a list, most of them empty
      if (list == null ||
          list.length == 0)
        return;
      // a scatter is cut from ONE litter pack, whose value its manifest cap already fitted to the
      // ground (no darkening on top)
      var name = list[0].img;
      var atlas = d.sprites.atlasTex(name, false, 1.0);
      if (atlas == null)
        return;
      for (s in list)
        {
          var r = d.sprites.contentRect(name, s.ix, s.iy, false);
          if (r == null)
            continue;
          var w = CityConfig.cellToWorld(s.col + s.dx, s.row + s.dy);
          var op = d.radiusOp(w.x, w.z);
          if (op <= 0.001)
            continue;
          // geometry is a unit quad, so bake the content footprint (SIZE * fw/fh) into the size. a
          // fragment's scale is its drawn longest side in world units (render.world.Debris.sized).
          // height off floorYAt and not floorY: the quad sits at s.col + s.dx, up to a quarter cell
          // off centre, and floorY answers about the CENTRE — see RenderConfig.DECAL.groundLift for
          // what that cost on the highway
          var k = s.scale / (Sprites.SIZE * Math.max(r.fw, r.fh));
          d.batch.add(atlas, r, w.x, WorldCtx.floorYAt(w.x, w.z) + RenderConfig.DECAL.groundLift, w.z,
            Sprites.SIZE * r.fw * k, Sprites.SIZE * r.fh * k, s.angle, op, 1.0, 0.0);
        }
    }
}
