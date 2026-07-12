package render.choreo;

import citygen.CityConfig;
import entities.Entity;
import render.RenderConfig;
import render.anim.MeleeLunge;

// melee choreography: attacker lunges toward the target and, on the lunge landing, fires the impact
// beat — plays the attack sound, shakes the target, and throws blood (bloody weapons)
class Melee {

// choreograph a melee strike. returns true if it took over the sound (caller then stays silent to
// avoid a double play); false when no attacker actor, so the caller plays the sound itself
  public static function play(c:Choreo, atkE:Entity, tgtE:Entity,
      atkCol:Int, atkRow:Int, tgtCol:Int, tgtRow:Int,
      soundFile:String, attackEffect:String, spawnBlood:Bool, bloodRow:Int, bloodFirstCol:Int):Bool
    {
      if (atkE == null)
        return false;
      // lunge reach: unit vector attacker->target, scaled to a fraction of a cell
      var a = CityConfig.cellToWorld(atkCol, atkRow);
      var b = CityConfig.cellToWorld(tgtCol, tgtRow);
      var dx = b.x - a.x, dz = b.z - a.z;
      var len = Math.sqrt(dx * dx + dz * dz);
      if (len < 0.001)
        {
          dx = 0;
          dz = 1;
          len = 1;
        }
      var reach = RenderConfig.MELEE.lungeReach * CityConfig.CELL;
      // the impact beat, fired when the lunge lands
      var onDone = function() {
        if (soundFile != null)
          c.game.scene.sounds.play(soundFile, { x: tgtCol, y: tgtRow });
        if (tgtE != null)
          c.actors.hitShake(tgtE);
        if (spawnBlood)
          c.actors.burst(tgtCol, tgtRow, dx, dz, bloodRow, bloodFirstCol);
        // the attack arc for the swing attacker->target, at each end's chest height. the attacker
        // origin is its *lunged* position (it has already reached toward the target at the apex),
        // so a travelling effect (punch) starts from there, not the resting cell
        if (attackEffect != null)
          {
            var ch = render.particles.Sprites.SIZE * 0.4;
            c.actors.attackFX(attackEffect,
              a.x + dx / len * reach, render.world.WorldCtx.floorY(atkCol, atkRow) + ch, a.z + dz / len * reach,
              b.x, render.world.WorldCtx.floorY(tgtCol, tgtRow) + ch, b.z);
          }
      };
      var lunge = new MeleeLunge(RenderConfig.MELEE.lungeMs,
        dx / len * reach, dz / len * reach, onDone);
      // if the attacker has no live billboard (off-screen), fire the beat now so nothing is lost
      if (!c.actors.playFx(atkE, lunge))
        onDone();
      return true;
    }
}
