// AI for blackops agents

package ai;

import ai.AI;
import _AIState;
import game.Game;
import const.*;

class BlackopsAI extends HumanAI
{
//  public var isBackup: Bool; // is this AI itself backup?
//  var isBackupCalled: Bool; // did this ai called for backup already?

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
      type = 'blackops';
      name.unknown = 'blackops agent';
      name.unknownCapped = 'Blackops agent';
      soundsID = 'team';
      isAggressive = true;
      isRelentless = true;
      inventory.clear();

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
          if (Std.random(100) < 50)
            inventory.addID(
              Std.random(100) < 75 ? 'assaultRifle' : 'combatShotgun');
          else inventory.addID('stunRifle');
          skills.addID(SKILL_RIFLE, 70 + Std.random(25));
          skills.addID(SKILL_SHOTGUN, 70 + Std.random(25));
          skills.addID(SKILL_PISTOL, 70 + Std.random(25));
          inventory.addID('fullBodyArmor', true);
        }

      if (inventory.clothing.id == 'fullBodyArmor')
        {
          var tmp = game.scene.atlas.get('blackops-heavy', isMale);
          tile = tmp.tile;
          tileAtlasX = tmp.x;
          tileAtlasY = tmp.y;
        }

//      isBackup = false;
//      isBackupCalled = false;
    }

// called after load or creation
  public override function initPost(onLoad: Bool)
    {
      super.initPost(onLoad);
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
