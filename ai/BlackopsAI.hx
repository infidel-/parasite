// AI for blackops agents 

package ai;

import ai.AI;
import _AIState;
import game.Game;

class BlackopsAI extends HumanAI
{
//  public var isBackup: Bool; // is this AI itself backup?
//  var isBackupCalled: Bool; // did this ai called for backup already?

  public function new(g: Game, vx: Int, vy: Int)
    {
      super(g, vx, vy);

      type = 'blackops';
      name.unknown = 'blackops agent';
      name.unknownCapped = 'Blackops agent';
      sounds = [
        '' + REASON_DAMAGE => [
          { text: '*GRUNT*', radius: 2, alertness: 5, params: null },
          { text: '*GROAN*', radius: 2, alertness: 5, params: null },
          ],
        '' + AI_STATE_IDLE => [
          { text: 'Huh?', radius: 0, alertness: 0, params: { minAlertness: 25 }  },
          { text: 'Whu?', radius: 0, alertness: 0, params: { minAlertness: 25 }  },
          { text: 'What the?', radius: 0, alertness: 0, params: { minAlertness: 50 }  },
          { text: 'BOGEY!', radius: 0, alertness: 0, params: { minAlertness: 75 } },
          ],
        '' + AI_STATE_ALERT => [
          { text: 'TANGO!', radius: 7, alertness: 10, params: null },
          ],
        '' + AI_STATE_HOST => [
          { text: '*moan*', radius: 2, alertness: 5, params: null },
          { text: '*MOAN*', radius: 3, alertness: 5, params: null },
          ]
        ];
      isAggressive = true;
      inventory.addID(Std.random(100) < 70 ? 'assaultRifle' : 'combatShotgun');
      inventory.addID('pistol');
      skills.addID(SKILL_RIFLE, 60 + Std.random(25));
      skills.addID(SKILL_SHOTGUN, 60 + Std.random(25));
      skills.addID(SKILL_PISTOL, 60 + Std.random(25));

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
