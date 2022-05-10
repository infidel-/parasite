// debug actions (area mode)

package game;

import ai.*;
import objects.*;
import const.EvolutionConst;

class DebugArea
{
  var game: Game;

  public var actions: Array<{ name: String, func: Dynamic }>;

  public function new(g: Game)
    {
      game = g;

      actions = [
        {
          name: 'Gain host',
          func: function()
            {
              if (game.player.state != PLR_STATE_PARASITE)
                {
                  trace('Must be in default state: ' + game.player.state);
                  return;
                }

              // spawn AI, attach to it and invade
              var ai = new CivilianAI(game, game.playerArea.x, game.playerArea.y);
              game.area.addAI(ai);
              game.playerArea.debugAttachAndInvadeAction(ai);
              game.player.hostControl = 100;

              // give weapon
              ai.inventory.addID('pistol');
              ai.skills.addID(SKILL_PISTOL, 25 + Std.random(25));
              ai.inventory.addID('stunner');
              ai.skills.addID(SKILL_FISTS, 50 + Std.random(25));
        //      ai.organs.addID(IMP_CAMO_LAYER);
        //      ai.organs.addID(IMP_DECAY_ACCEL);

              // computer
              ai.inventory.addID('smartphone');
              ai.skills.addID(SKILL_COMPUTER, 10 + Std.random(20));
            }
        },

        {
          name: 'Gain host (advanced)',
          func: function()
            {
              if (game.player.state != PLR_STATE_PARASITE)
                {
                  trace('Must be in default state: ' + game.player.state);
                  return;
                }

              // spawn AI, attach to it and invade
              var ai = new CivilianAI(game, game.playerArea.x, game.playerArea.y);
              game.area.addAI(ai);
              game.playerArea.debugAttachAndInvadeAction(ai);
              game.player.hostControl = 100;

              ai.inventory.addID('pistol');
              ai.skills.addID(SKILL_PISTOL, 25 + Std.random(25));
              ai.inventory.addID('smartphone');
              ai.inventory.addID('laptop');
              ai.skills.addID(SKILL_COMPUTER, 20 + Std.random(20));
              game.player.addKnownItem('pistol');
              game.player.addKnownItem('smartphone');
              game.player.addKnownItem('laptop');

              game.player.evolutionManager.state = 2;
              game.player.vars.organsEnabled = true;
              game.player.vars.inventoryEnabled = true;
              game.player.vars.skillsEnabled = true;
              game.player.vars.timelineEnabled = true;
              game.timeline.unlock();
              for (ev in game.timeline.iterator())
                if (!ev.isHidden)
                  for (n in ev.notes)
                    n.clues = 3;
              game.timeline.learnClues(game.timeline.getStartEvent(), true);
              game.timeline.learnClues(game.timeline.getStartEvent(), true);
              game.timeline.learnClues(game.timeline.getStartEvent(), true);
              game.timeline.getStartEvent().learnNPC();
              game.timeline.getStartEvent().learnNPC();
              game.timeline.getStartEvent().learnNPC();
              game.goals.receive(GOAL_PROBE_BRAIN);
              game.goals.complete(GOAL_PROBE_BRAIN);

              game.player.vars.npcEnabled = true;
              game.player.vars.searchEnabled = true;

              // brain probe
              game.player.evolutionManager.addImprov(IMP_BRAIN_PROBE, 2);

              // start habitat branch
        //      game.goals.receive(GOAL_GROW_ORGAN);
        //      game.goals.complete(GOAL_GROW_ORGAN);
//              game.player.skills.addID(KNOW_HABITAT, 100);
              game.player.evolutionManager.addImprov(IMP_MICROHABITAT, 1);
            }
        },

        {
          name: 'Complete current evolution',
          func: function()
            {
              game.player.evolutionManager.turn(2000, true);
              game.player.energy = 100;
              game.player.host.energy = 100;
            }
        },

        {
          name: 'Complete current organ',
          func: function()
            {
              if (game.player.state != PLR_STATE_HOST)
                return;

              game.player.host.organs.debugCompleteCurrent();
            }
        },

        {
          name: 'Clear AI',
          func: function()
            {
              for (ai in game.area.getAIinRadius(game.playerArea.x, game.playerArea.y, 100, false))
                if (ai != game.player.host)
                  game.area.removeAI(ai);
            }
        },

        {
          name: 'Spawn a cop',
          func: function()
            {
              var ai = new PoliceAI(game, game.playerArea.x, game.playerArea.y);
              ai.inventory.clear();
/*
              ai.inventory.addID('baton');
              ai.skills.addID(SKILL_BATON, 50 + Std.random(25));
*/
              ai.inventory.addID('radio');
              ai.inventory.addID('stunner');
              ai.skills.addID(SKILL_FISTS, 50 + Std.random(25));
              game.area.addAI(ai);
            }
        },

        {
          name: 'Spawn a body',
          func: function()
            {
              var o = new BodyObject(game, game.area.id,
                game.playerArea.x, game.playerArea.y, 'civilian');
              o.organPoints = 10;
        //      o.setDecay(1);

              game.area.debugShowObjects();
            }
        },
      ];
    }


// call an action
  public function action(idx: Int)
    {
      var a = actions[idx];
      if (a == null)
        {
          trace("No such area debug action " + idx);
          return;
        }
      Reflect.callMethod(this, a.func, []);
    }
}
