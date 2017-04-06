// AI for team members

package ai;

import ai.AI;
import _AIState;
import game.Game;

class TeamMemberAI extends HumanAI
{
  public function new(g: Game, vx: Int, vy: Int)
    {
      super(g, vx, vy);
      type = 'civilian';
      name.unknown = 'random civilian';
      name.unknownCapped = 'Random civilian';
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
      skills.addID(SKILL_PISTOL, 40 + Std.random(20));
      inventory.addID('pistol');

      // these only spawn when they're useful
      if (game.player.vars.searchEnabled)
        {
          skills.addID(SKILL_COMPUTER, 20 + Std.random(20));
          inventory.addID('smartphone');
        }
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
      // team member was alerted at some point before despawn, raise priority
      if (wasAlerted)
        game.group.raisePriority(10);

      // team member was noticed but never alerted, raise distance instead
      else if (wasNoticed)
        game.group.raiseTeamDistance(10);
    }


// event: on AI death
  public override function onDeath()
    {
      // call group hook
      game.group.teamMemberDeath();
    }


// event: on being noticed by player
  public override function onNotice()
    {
      game.log('You feel someone watching you.');
    }
}
