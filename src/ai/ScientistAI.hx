// AI for scientists

package ai;

import ai.AI;
import _AIState;
import game.Game;
import const.*;

class ScientistAI extends HumanAI
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
      type = 'scientist';
      name.unknown = 'random scientist';
      name.unknownCapped = 'Random scientist';
      soundsID = 'scientist';

      if (Std.random(100) < 75)
        {
          skills.addID(SKILL_COMPUTER, 10 + Std.random(20));
          inventory.addID('smartphone');
        }
    }

// called after load or creation
  public override function initPost(onLoad: Bool)
    {
      super.initPost(onLoad);
    }

// event: on state change
  public override function onStateChange()
    {
      // TODO: in labs run for help?
      // try to call security on next turn if not struggling with parasite
      if (state == AI_STATE_ALERT && !parasiteAttached)
        {
          // cannot call security without a phone
          if (!inventory.has('smartphone') &&
              !inventory.has('mobilePhone'))
            return;

          // no reception in habitat
          if (game.area.isHabitat)
            {
              log('fumbles with something in its hands. "Shit! No reception!"');
              return;
            }

          var time = 1;
          if (game.player.difficulty == UNSET ||
              game.player.difficulty == EASY)
            time = 2;
          game.managerArea.addAI(this, AREAEVENT_CALL_LAW, time);
        }
    }
}
