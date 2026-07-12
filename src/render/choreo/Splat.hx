package render.choreo;

import render.RenderConfig;

// splat-only choreography (bleeding drips, black noise — non-combat splats with no attack beat): a
// small unbiased 3D blood burst at the cell (biased away from the source when given) whose drops land
// as the same persisted SPLAT decals the 2D splat would write, plus the splat-land sound
class Splat {

// choreograph a non-combat splat. returns true if the view took over (caller then skips the 2D
// particle)
  public static function play(c:Choreo, type:String, x:Int, y:Int, ?source:_Point):Bool
    {
      var dx = 0.0;
      var dz = 0.0;
      if (source != null)
        {
          dx = x - source.x;
          dz = y - source.y;
        }
      var ic = particles.ParticleSplat.bloodIcon(type);
      c.actors.burst(x, y, dx, dz, ic.row, ic.col, RenderConfig.BLOOD.dripDrops);
      c.game.scene.sounds.play('fx-splat', { x: x, y: y });
      return true;
    }
}
