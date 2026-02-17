// AI for dogs

package ai;

import ai.AI;
import game.Game;

class DogAI extends AI
{
  public function new(g: Game, vx: Int, vy: Int)
    {
      super(g, vx, vy);
      init();
      initPost(false);
    }

// init object before loading/post creation
  public override function init()
    {
      super.init();
      type = 'dog';
      name = {
        real: 'dog',
        realCapped: 'dog',
        unknown: 'dog',
        unknownCapped: 'dog'
      };
      soundsID = 'dog';

      strength = 2 + Std.random(4);
      constitution = 2 + Std.random(4);
      intellect = 1;
      psyche = 1 + Std.random(1);

      skills.addID(SKILL_ATTACK, 65);

      derivedStats();
    }

// called after load or creation
  public override function initPost(onLoad: Bool)
    {
      super.initPost(onLoad);
    }

// check if this AI should use "it" pronouns
  public override function isIt(): Bool
    {
      return true;
    }

// hook: ai-specific bonus actions
  public override function updateActionList()
    {
      game.ui.hud.addAction({
        id: 'bark',
        type: ACTION_HOST,
        name: 'Bark',
        canRepeat: true,
        energy: 5
      });
    }

// hook: run action
  public override function action(action: _PlayerAction)
    {
      // bark
      game.scene.sounds.play('dog-bark');

      // get a list of AIs in that radius without los checks and give alertness bonus
      var list = game.area.getAIinRadius(x, y, 6, false);
      for (ai in list)
        if (ai.state == AI_STATE_IDLE ||
            ai.state == AI_STATE_MOVE_TARGET ||
            ai.state == AI_STATE_INVESTIGATE)
          {
            ai.roamTargetX = x;
            ai.roamTargetY = y;
            ai.state = AI_STATE_INVESTIGATE;
            ai.alertness += 1;
            ai.log('investigates the noise.');
          }
    }
}
