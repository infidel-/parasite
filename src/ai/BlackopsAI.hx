// AI for blackops agents

package ai;

import game.Game;

class BlackopsAI extends HumanAI
{
//  public var isBackup: Bool; // is this AI itself backup?
//  var isBackupCalled: Bool; // did this ai called for backup already?

  public function new(g: Game, vx: Int, vy: Int)
    {
      super(g, vx, vy);
      init();
      var bonusStat = 1;
      // team level changes loadout
      if (game.group.team.level == 1)
        {
          inventory.addID(
            Std.random(100) < 75 ? 'assaultRifle' : 'combatShotgun');
          skills.addID(SKILL_RIFLE, 60 + Std.random(25));
          skills.addID(SKILL_SHOTGUN, 60 + Std.random(25));
          skills.addID(SKILL_PISTOL, 60 + Std.random(25));
          inventory.addID('kevlarArmor', true);
        }

      else if (game.group.team.level == 2)
        {
          inventory.addID(
            Std.random(100) < 75 ? 'assaultRifle' : 'combatShotgun');
          skills.addID(SKILL_RIFLE, 65 + Std.random(25));
          skills.addID(SKILL_SHOTGUN, 65 + Std.random(25));
          skills.addID(SKILL_PISTOL, 65 + Std.random(25));
          inventory.addID(
            Std.random(100) < 75 ? 'kevlarArmor' : 'fullBodyArmor',
            true);
        }

      else if (game.group.team.level == 3)
        {
          bonusStat = 2;
          if (Std.random(100) < 75)
            inventory.addID(
              Std.random(100) < 75 ? 'assaultRifle' : 'combatShotgun');
          else inventory.addID('stunRifle');
          skills.addID(SKILL_RIFLE, 70 + Std.random(25));
          skills.addID(SKILL_SHOTGUN, 70 + Std.random(25));
          skills.addID(SKILL_PISTOL, 70 + Std.random(25));
          inventory.addID(
            Std.random(100) < 50 ? 'kevlarArmor' : 'fullBodyArmor',
            true);
        }

      else if (game.group.team.level == 4)
        {
          bonusStat = 3;
          if (Std.random(100) < 50)
            inventory.addID(
              Std.random(100) < 75 ? 'assaultRifle' : 'combatShotgun');
          else inventory.addID('stunRifle');
          skills.addID(SKILL_RIFLE, 70 + Std.random(25));
          skills.addID(SKILL_SHOTGUN, 70 + Std.random(25));
          skills.addID(SKILL_PISTOL, 70 + Std.random(25));
          inventory.addID('fullBodyArmor', true);
        }
      // higher stats that ordinary humans
      strength = 4 + bonusStat + Std.random(6 - bonusStat);
      constitution = 4 + bonusStat + Std.random(6 - bonusStat);
      intellect = 4 + bonusStat + Std.random(6 - bonusStat);
      psyche = 4 + bonusStat + Std.random(6 - bonusStat);

      if (inventory.clothing.id == 'fullBodyArmor')
        {
          var tmp = game.scene.images.getAI('blackops-heavy', isMale);
          tileAtlasX = tmp.x;
          tileAtlasY = tmp.y;
        }
      initPost(false);
    }

// init object before loading/post creation
  public override function init()
    {
      super.init();
      type = 'blackops';
      name.unknown = 'blackops agent';
      name.unknownCapped = 'Blackops agent';
      soundsID = 'team';
      isAggressive = true;
      isRelentless = true;
      inventory.clear();

//      isBackup = false;
//      isBackupCalled = false;
    }

// called after load or creation
  public override function initPost(onLoad: Bool)
    {
      super.initPost(onLoad);
    }

// event: on AI probed
  public override function onBrainProbe()
    {
      // knowledge about group and false memories
      game.group.brainProbe();
      game.goals.receive(GOAL_LEARN_FALSE_MEMORIES);
    }

// event hook: on AI death
// NOTE: called after the AI is removed from the area list!
  public override function onDeath()
    {
      if (game.group.team != null)
        game.group.team.onBlackopsDeath();
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
