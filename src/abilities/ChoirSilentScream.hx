// choir of discord silent scream ability
package abilities;

import ai.AI;
import effects.BlackNoise;
import particles.ParticleSilentScream;

class ChoirSilentScream extends Ability
{
  // effect radius (cells); the 3D scream visuals (RenderConfig.SCREAM.radiusCells) derive from it
  public static inline var RADIUS = 5;

  public function new()
    {
      super();
    }

// init object before loading/post creation
  public override function init()
    {
      super.init();
      id = ABILITY_CHOIR_SILENT_SCREAM;
      name = 'silent scream';
    }

// handle silent scream pulse before regular attacks
  public override function logicAttack(ai: AI, target: AttackTarget): Bool
    {
      if (timeout > 0)
        {
          timeout--;
          return false;
        }
      if (Std.random(100) >= 35)
        return false;
      ai.log('screams in silence.');

      // apply black noise to nearby AIs
      var area = target.game.area;
      var affected = 0;
      for (other in area.getAIinRadius(ai.x, ai.y, RADIUS, false))
        {
          if (other == ai ||
              other.state == AI_STATE_DEAD)
            continue;
          var turns = 2 + Std.random(3);
          other.onEffect(new BlackNoise(target.game, turns));
          other.log(' exudes drops of black blood from his orifices.');
          affected++;
        }
      if (affected == 0)
        return false;

      // 3D street view live: expanding dome + screen shockwave instead of the flat 2D rings
      var scene = target.game.scene;
      if (scene.city3d == null ||
          !scene.city3d.playScream(ai.x, ai.y))
        new ParticleSilentScream(scene, {
          x: ai.x,
          y: ai.y
        });
      target.game.scene.sounds.play('ability-silent-scream', {
        x: ai.x,
        y: ai.y,
        always: true,
      });
      timeout = 4;
      return true;
    }
}
