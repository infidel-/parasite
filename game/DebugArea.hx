// debug actions (area mode)

package game;

import ai.*;
import objects.*;
import const.EvolutionConst;

class DebugArea
{
  var game: Game;
  var area: Area;

  public var actions: Array<{ name: String, func: Dynamic }>;

  public function new(g: Game, a: Area)
    {
      game = g;
      area = a;

      actions = [
        {
          name: "Remove energy spend without a host",
          func: function()
            {
              game.player.vars.areaEnergyPerTurn = 0;
              game.log('Energy per turn removed.');
            }
        },
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
              var ai = new CivilianAI(game, area.player.x, area.player.y);
              area.addAI(ai);
              area.player.debugAttachAndInvadeAction(ai);
              game.player.hostControl = 100;

              // give weapon
              ai.inventory.addID('pistol');
              ai.skills.addID(SKILL_PISTOL, 25 + Std.random(25));
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
              var ai = new CivilianAI(game, area.player.x, area.player.y);
              area.addAI(ai);
              area.player.debugAttachAndInvadeAction(ai);
              game.player.hostControl = 100;

              ai.inventory.addID('pistol');
              ai.skills.addID(SKILL_PISTOL, 25 + Std.random(25));
              ai.inventory.addID('smartphone');
              ai.skills.addID(SKILL_COMPUTER, 20 + Std.random(20));

              game.player.evolutionManager.state = 2;
              game.player.vars.organsEnabled = true;
              game.player.vars.inventoryEnabled = true;
              game.player.vars.skillsEnabled = true;
              game.player.vars.timelineEnabled = true;
              game.timeline.unlock();
              game.timeline.learnClue(game.timeline.getStartEvent(), true);
              game.timeline.learnClue(game.timeline.getStartEvent(), true);
              game.timeline.learnClue(game.timeline.getStartEvent(), true);
              game.timeline.getStartEvent().learnNPC();
              game.timeline.getStartEvent().learnNPC();
              game.timeline.getStartEvent().learnNPC();

              game.player.vars.npcEnabled = true;
              game.player.vars.searchEnabled = true;

              // brain probe
              game.player.evolutionManager.addImprov(IMP_BRAIN_PROBE, 2);

              // start habitat branch
        //      game.player.goals.receive(GOAL_GROW_ORGAN);
        //      game.player.goals.complete(GOAL_GROW_ORGAN);
              game.player.skills.addID(KNOW_HABITAT, 100); 
              game.player.evolutionManager.addImprov(IMP_MICROHABITAT, 1);
            }
        },
        {
          name: 'Toggle LOS',
          func: function()
            {
              game.player.vars.losEnabled = !game.player.vars.losEnabled;
              area.updateVisibility();
              game.log('LOS checks for player toggled.');
            }
        },
        {
          name: 'Enter sewers',
          func: function()
            {
              game.scene.setState(HUDSTATE_DEFAULT);
              game.setLocation(Game.LOCATION_REGION);
            }
        },
        {
          name: 'Complete current evolution',
          func: function()
            {
              game.player.evolutionManager.turn(2000);
              game.player.energy = 100;
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
          name: 'Gain all improvements at level 0',
          func: function()
            {
              for (imp in EvolutionConst.improvements)
                if (!game.player.evolutionManager.isKnown(imp.id))
                  game.player.evolutionManager.addImprov(imp.id);
              game.player.evolutionManager.state = 2;
              game.log('All evolution improvements gained at level 0');
            }
        },
        {
          name: 'Gain all improvements at max level',
          func: function()
            {
              for (imp in EvolutionConst.improvements)
                if (!game.player.evolutionManager.isKnown(imp.id))
                  game.player.evolutionManager.addImprov(imp.id);
          
              for (imp in game.player.evolutionManager.getList())
                {
                  imp.level = 3;
                  imp.ep = EvolutionConst.epCostImprovement[imp.level];
                }
              game.player.evolutionManager.state = 2;
              game.log('All evolution improvements gained at max level');
            }
        },
        {
          name: 'Clear AI',
          func: function()
            {
              for (ai in area.getAIinRadius(area.player.x, area.player.y, 100, false))
                if (ai != game.player.host)
                  area.removeAI(ai);
            }
        },
        {
          name: 'Spawn a cop',
          func: function()
            {
              var ai = new PoliceAI(game, area.player.x, area.player.y);
              ai.inventory.clear();
              ai.inventory.addID('baton');
              ai.skills.addID(SKILL_BATON, 50 + Std.random(25));
              area.addAI(ai);
            }
        },
        {
          name: 'Spawn a body',
          func: function()
            {
//              var o = area.createObject(area.player.x, area.player.y, 'body', 'civilian');
              var o = new BodyObject(game, area.player.x, area.player.y, 'civilian');
              o.isHumanBody = true;
              o.organPoints = 10;
        //      o.setDecay(1);

              area.debugShowObjects();
            }
        },
        {
          name: 'Show area manager queue',
          func: function()
            {
              game.area.manager.debugShowQueue();
            }
        },
        {
          name: 'Set area alertness to 100',
          func: function()
            {
              game.area.debugSetMaxAlertness();
            }
        },
        {
          name: 'Unlock timeline',
          func: function()
            {
              game.log('Timeline unlocked.');
              game.player.skills.increase(KNOW_SOCIETY, 1);
              game.player.skills.increase(KNOW_SOCIETY, 24);
            }
        },
        {
          name: 'Open timeline',
          func: function()
            {
              game.log('Timeline opened.');
              for (e in game.timeline)
                {
                  e.locationKnown = true;
                  for (n in e.notes)
                    n.isKnown = true;

                  for (npc in e.npc)
                    {
                      npc.nameKnown = true;
                      npc.jobKnown = true;
                      npc.areaKnown = true;
                      npc.isDeadKnown = true;
                    }
                }
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
