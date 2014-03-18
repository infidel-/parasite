// AI for police 

package ai;

class PoliceAI extends HumanAI
{
  public var isBackup: Bool; // is this AI itself backup?
  var isBackupCalled: Bool; // did this ai called for backup already?

  public function new(g: Game, vx: Int, vy: Int)
    {
      super(g, vx, vy);

      type = 'police';
      name.unknown = 'police officer';
      name.unknownCapped = 'Police officer';
      sounds = [
        AI.STATE_IDLE => [
          { text: 'Huh?', radius: 0, alertness: 0, params: { minAlertness: 25 }  },
          { text: 'Whu?', radius: 0, alertness: 0, params: { minAlertness: 25 }  },
          { text: 'What the?', radius: 0, alertness: 0, params: { minAlertness: 50 }  },
          ],
        AI.STATE_ALERT => [
          { text: 'STOP!', radius: 7, alertness: 10, params: null },
          ]
        ];
      isAggressive = true;
      inventory.addID('baton');
      skills.addID('baton', 50 + Std.random(25));

      isBackup = false;
      isBackupCalled = false;
    }


// event: on being attacked 
  public override function onAttack()
    {
      // if this ai has not called for backup yet
      // try it on next turn if not struggling with parasite
      if (!isBackupCalled && state == AI.STATE_ALERT && !parasiteAttached)
        {
          isBackupCalled = true;
          game.areaManager.addAI(this, AreaManager.EVENT_CALL_POLICE_BACKUP, 1);
        }
    }


// event: on state change
  public override function onStateChange()
    {
      // backup despawns when it loses alert state
      // i could make it roam around for a bit but it's probably not worth it
      if (state == AI.STATE_IDLE && isBackup)
        game.area.destroyAI(this);
    }
}
