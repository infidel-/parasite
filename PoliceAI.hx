// AI for police 

class PoliceAI extends HumanAI
{
  var backupCalled: Bool; // did this ai called for backup already?

  public function new(g: Game, vx: Int, vy: Int)
    {
      super(g, vx, vy);

      type = 'police';
      name.unknown = 'police officer';
      name.unknownCapped = 'Police officer';
      isAggressive = true;
      inventory.addID('baton');
      skills.addID('baton', 50 + Std.random(25));

      backupCalled = false;
    }


// event: on being attacked 
  public override function onAttack()
    {
      // if this ai has not called for backup yet
      // try it on next turn if not struggling with parasite
      if (!backupCalled && state == AI.STATE_ALERT && !parasiteAttached)
        {
          backupCalled = true;
          game.areaManager.addAI(this, AreaManager.EVENT_CALL_POLICE_BACKUP, 1);
        }
    }
}
