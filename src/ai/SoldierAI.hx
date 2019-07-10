// AI for soldiers 

package ai;

import ai.AI;
import _AIState;
import game.Game;
import const.*;

class SoldierAI extends HumanAI
{
//  public var isBackup: Bool; // is this AI itself backup?
//  var isBackupCalled: Bool; // did this ai called for backup already?

  public function new(g: Game, vx: Int, vy: Int)
    {
      super(g, vx, vy);

      type = 'soldier';
      name.unknown = 'soldier';
      name.unknownCapped = 'Soldier';
      sounds = SoundConst.soldier;
      isAggressive = true;
      inventory.addID('assaultRifle');
      skills.addID(SKILL_RIFLE, 40 + Std.random(25));

//      isBackup = false;
//      isBackupCalled = false;
    }

/*
// event: on being attacked 
  public override function onAttack()
    {
      // if this ai has not called for backup yet
      // try it on next turn if not struggling with parasite
      if (!isBackupCalled && state == AI_STATE_ALERT && !parasiteAttached)
        {
          isBackupCalled = true;
          game.area.manager.addAI(this, AreaManager.EVENT_CALL_POLICE_BACKUP, 1);
        }
    }


// event: on state change
  public override function onStateChange()
    {
      // backup despawns when it loses alert state
      // i could make it roam around for a bit but it's probably not worth it
      if (state == AI_STATE_IDLE && isBackup)
        game.area.removeAI(this);
    }*/ 
}
