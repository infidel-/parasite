// AI for team members

package ai;

import ai.AI;
import _AIState;
import game.Game;
import const.*;

class TeamMemberAI extends HumanAI
{
  public function new(g: Game, vx: Int, vy: Int)
    {
      super(g, vx, vy);
      init();
      // team level changes loadout
      if (game.group.team.level == 1)
        {
          skills.addID(SKILL_PISTOL, 40 + Std.random(20));
          inventory.addID('pistol');
        }
      else if (game.group.team.level == 2)
        {
          skills.addID(SKILL_PISTOL, 45 + Std.random(20));
          inventory.addID('pistol');
          if (Std.random(100) < 25)
            inventory.addID('kevlarArmor', true);
        }
      else if (game.group.team.level == 3)
        {
          skills.addID(SKILL_PISTOL, 50 + Std.random(20));
          inventory.addID('pistol');
          if (Std.random(100) < 50)
            inventory.addID('kevlarArmor', true);
        }
      else if (game.group.team.level == 4)
        {
          skills.addID(SKILL_PISTOL, 55 + Std.random(20));
          inventory.addID('pistol');
          if (Std.random(100) < 75)
            inventory.addID('kevlarArmor', true);
        }
      // team members have somewhat better chat skills
      if (Std.random(100) < 70)
        skills.addID(SKILL_PSYCHOLOGY, 30 + Std.random(10));
      if (Std.random(100) < 60)
        skills.addID(SKILL_DECEPTION, 30 + Std.random(10));
      if (Std.random(100) < 70)
        skills.addID(SKILL_COERCION, 30 + Std.random(10));
      if (Std.random(100) < 50)
        skills.addID(SKILL_COAXING, 30 + Std.random(10));

      skills.addID(SKILL_COMPUTER, 20 + Std.random(20));
      inventory.addID('smartphone');
      initPost(false);
    }

// init object before loading/post creation
  public override function init()
    {
      super.init();
      if (game.area.typeID == AREA_FACILITY)
        {
          type = 'scientist';
          name.unknown = 'random scientist';
          name.unknownCapped = 'Random scientist';
        }
      else if (game.area.typeID == AREA_MILITARY_BASE)
        {
          type = 'soldier';
          name.unknown = 'soldier';
          name.unknownCapped = 'Soldier';
        }
      else
        {
          type = 'civilian';
          name.unknown = 'random civilian';
          name.unknownCapped = 'Random civilian';
        }
      soundsID = 'team';
      isAggressive = true;
      isTeamMember = true;
    }

// called after load or creation
  public override function initPost(onLoad: Bool)
    {
      super.initPost(onLoad);
    }

// event: on state change
  public override function onStateChange()
    {
      // try to call backup on next turn if not struggling with parasite
      if (state == AI_STATE_ALERT && !parasiteAttached)
        {
          // cannot call backup without a phone
          if (!inventory.has('smartphone') &&
              !inventory.has('mobilePhone'))
            return;

          // no reception in habitat
          if (game.area.isHabitat)
            {
              log('fumbles with something in its hands. "Shit! No reception!"');

              return;
            }

          game.managerArea.addAI(this, AREAEVENT_CALL_TEAM_BACKUP, 1);
        }
    }

// event: despawn live AI
  public override function onRemove()
    {
      // when team is in ambush, disable evasion logic
      if (game.group.team != null &&
          game.group.team.state == TEAM_AMBUSH)
        return;

      // team member was alerted at some point before despawn, raise priority
      if (wasAlerted)
        game.group.raisePriority(10);

      // team member was noticed but never alerted, raise distance instead
      else if (wasNoticed)
        game.group.raiseTeamDistance(1);
    }

// event: on AI death
// NOTE: called after the AI is removed from the area list!
  public override function onDeath()
    {
      // call group hook
      game.group.onTeamMemberDeath();
    }

// event: on AI probed
  public override function onBrainProbe()
    {
      // knowledge about group and false memories
      game.group.brainProbe();
      game.goals.receive(GOAL_LEARN_FALSE_MEMORIES);
    }

// event: on being noticed by player
  public override function onNotice()
    {
      // do not show too often
      if (game.turns - game.group.teamMemberLastNoticed < 8 + Std.random(4))
        return;
      game.group.teamMemberLastNoticed = game.turns;
      game.log('You feel someone is watching.', COLOR_ALERT);
      game.profile.addPediaArticle('msgWatching');
      game.ui.hud.showBlinkingText();
      game.scene.sounds.play('team-notify');
    }
}
