package render.choreo;

import three.Three;
import citygen.CityConfig;
import render.RenderConfig;

// thrown-projectile choreography (spit clot / spine needle / blood clot): a sprite blob with trailing
// drips races source->target at chest height, and the impact splat beat (acid/slime/blood burst +
// splat sound) fires on arrival. 3D port of Particle.createProjectile
class Projectile {

// choreograph a thrown projectile. returns true if the view took over (caller then skips the 2D
// particle)
  public static function play(c:Choreo, type:String, sx:Int, sy:Int, tx:Int, ty:Int,
      hit:Bool, bloodType:String):Bool
    {
      var P = RenderConfig.PROJECTILE;
      // a missed needle flies past the target into a neighbour cell, like the 2D particle
      if (type == 'needle' &&
          !hit)
        {
          tx += Const.roll(-1, 1);
          ty += Const.roll(-1, 1);
        }
      var kind = switch (type)
        {
          case 'needle': P.needle;
          case 'blood': P.blood;
          default: P.spit;
        };
      // atlas cell of the blob sprite (the needle reuses the paralysis-spit dart, like 2D; a blood
      // clot flies as one of the blood-splat variants, the same cells the landed burst draws)
      var row = Const.ROW_EFFECT;
      var frame = switch (type)
        {
          case 'acidSpit': Const.FRAME_PARTICLE_ACID_SPIT;
          case 'slimeSpit': Const.FRAME_PARTICLE_SLIME_SPIT;
          case 'blood':
            var ic = particles.ParticleSplat.bloodIcon(bloodType);
            row = ic.row;
            ic.col + Std.random(particles.ParticleSplat.SPLAT_NUM);
          default: Const.FRAME_PARTICLE_PARALYSIS_SPIT;
        };
      // source/impact at chest height (the blood-burst convention)
      var sw = CityConfig.cellToWorld(sx, sy);
      var tw = CityConfig.cellToWorld(tx, ty);
      var ch = render.particles.Sprites.SIZE * 0.4;
      var src = new Vector3(sw.x, render.world.WorldCtx.floorY(sx, sy) + ch, sw.z);
      var dst = new Vector3(tw.x, render.world.WorldCtx.floorY(tx, ty) + ch, tw.z);
      // the impact splat variant: acid/slime always, blood always for a thrown clot and on a needle
      // hit, nothing for paralysis spit (mirrors the 2D onDeath splat chain)
      var splat = switch (type)
        {
          case 'acidSpit': 'acid';
          case 'slimeSpit': 'slime';
          case 'blood': bloodType;
          case 'needle': (hit ? bloodType : null);
          default: null;
        };
      // faint goop glow on the in-flight blob (acid/slime only)
      var glow = switch (type)
        {
          case 'acidSpit': RenderConfig.BLOOD.acidGlow;
          case 'slimeSpit': RenderConfig.BLOOD.slimeGlow;
          default: 0;
        };
      // the impact beat: the usual hit shake on the struck AI (looked up at impact time — it may
      // have died/moved during the flight) + the splat burst/sound, mirroring the 2D splat chain.
      // a blood clot lands on a spray cell, not on a struck actor, so it skips the hit reaction
      var onImpact = function() {
        if (hit &&
            type != 'blood')
          {
            var ai = c.game.area.getAI(tx, ty);
            if (ai != null &&
                ai.entity != null)
              c.actors.hitShake(ai.entity);
            // paralysis leaves no splat; stamp the curved-X impact mark on the target instead
            if (type == 'paralysisSpit')
              c.actors.attackFX('IMPACT', src.x, src.y, src.z, dst.x, dst.y, dst.z);
          }
        if (splat != null)
          {
            var ic = particles.ParticleSplat.bloodIcon(splat);
            c.actors.burst(tx, ty, tx - sx, ty - sy, ic.row, ic.col);
            c.game.scene.sounds.play('fx-splat', { x: tx, y: ty });
          }
      };
      c.actors.projectile({
        src: src,
        dst: dst,
        col: frame,
        row: row,
        glow: glow,
        scale: kind.scale,
        drips: kind.drips,
        travelMs: kind.travelMs,
        arc: kind.arc,
        onImpact: onImpact,
      });
      return true;
    }
}
