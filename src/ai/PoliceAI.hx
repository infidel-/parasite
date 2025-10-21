// AI for police

package ai;

import game.Game;

class PoliceAI extends HumanAI
{
  public var isBackup: Bool; // is this AI itself backup?
  var isBackupCalled: Bool; // did this ai called for backup already?

  public function new(g: Game, vx: Int, vy: Int)
    {
      super(g, vx, vy);
      init();
      // skill traits for police
      addTraitFromGroup('skill');
      if (Std.random(100) < 50)
        addTraitFromGroup('skill');
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
      // police have somewhat better chat skills
      if (Std.random(100) < 60)
        skills.addID(SKILL_PSYCHOLOGY, 20 + Std.random(10));
      if (Std.random(100) < 50)
        skills.addID(SKILL_DECEPTION, 20 + Std.random(10));
      if (Std.random(100) < 60)
        skills.addID(SKILL_COERCION, 20 + Std.random(10));
      if (Std.random(100) < 40)
        skills.addID(SKILL_COAXING, 20 + Std.random(10));
      initPost(false);
    }

// init object before loading/post creation
  public override function init()
    {
      super.init();
      type = 'police';
      name.unknown = 'police officer';
      name.unknownCapped = 'Police officer';
      soundsID = 'police';
      isAggressive = true;

      isBackup = false;
      isBackupCalled = false;
      var jobData = game.jobs.getRandom(type);
      job = jobData.name;
      income = jobData.income;
    }

// called after load or creation
  public override function initPost(onLoad: Bool)
    {
      super.initPost(onLoad);
    }

  // handles per-turn police lookout for criminals
  public override function turn()
    {
      super.turn();

      var seen = game.area.getAIinRadius(x, y, AI.VIEW_DISTANCE, true);
      for (other in seen)
        {
          if (other == this)
            continue;
          if (!other.didCrime)
            continue;
          if (Std.random(100) >= 80)
            continue;
          addEnemy(other);
          if (state == AI_STATE_IDLE)
            setState(AI_STATE_ALERT, REASON_WITNESS);
        }
    }

// event: on being attacked
  public override function onAttack()
    {
      // need radio
      if (!inventory.has('radio'))
        return;

      // if this ai has not called for backup yet
      // try it on next turn if not struggling with parasite
      if (!isBackupCalled &&
          state == AI_STATE_ALERT &&
          !parasiteAttached)
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
