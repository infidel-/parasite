// AI for police

package ai;

import ai.AI;
import _AIState;
import game.Game;
import const.*;

class PoliceAI extends HumanAI
{
  public var isBackup: Bool; // is this AI itself backup?
  var isBackupCalled: Bool; // did this ai called for backup already?

  public function new(g: Game, vx: Int, vy: Int)
    {
      super(g, vx, vy);
      init();
      loadPost();
    }

// init object before loading/post creation
  public override function init()
    {
      super.init();
      type = 'police';
      name.unknown = 'police officer';
      name.unknownCapped = 'Police officer';
      sounds = SoundConst.police;
      isAggressive = true;

      // chance of having stunner
      var ch = 20;
      if (game.area.info.isHighRisk)
        ch = 35;
      if (Std.random(100) < ch)
        {
          inventory.addID('stunner');
          skills.addID(SKILL_FISTS, 50 + Std.random(25));
        }
      else
        {
          inventory.addID('baton');
          skills.addID(SKILL_BATON, 50 + Std.random(25));
        }
      inventory.addID('radio');

      isBackup = false;
      isBackupCalled = false;
    }

// called after load or creation
  public override function loadPost()
    {
      super.loadPost();
    }


// event: on being attacked
  public override function onAttack()
    {
      // need radio
      if (!inventory.has('radio'))
        return;

      // if this ai has not called for backup yet
      // try it on next turn if not struggling with parasite
      if (!isBackupCalled && state == AI_STATE_ALERT && !parasiteAttached)
        {
          isBackupCalled = true;
          game.managerArea.addAI(this, AREAEVENT_CALL_BACKUP, 1);
        }
    }


// event: on state change
  public override function onStateChange()
    {
      // backup despawns when it loses alert state
      // i could make it roam around for a bit but it's probably not worth it
      if (state == AI_STATE_IDLE && isBackup)
        game.area.removeAI(this);
    }
}
