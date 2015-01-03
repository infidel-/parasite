// debug actions (area mode)

import ai.*;
import objects.*;

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
          func: removeEnergySpend
        },
        {
          name: 'Gain host',
          func: gainHost
        },
        {
          name: 'Gain host (advanced)', 
          func: gainHostAdvanced
        },
        {
          name: 'Toggle LOS',
          func: toggleLOS
        },
        {
          name: 'Enter sewers',
          func: enterSewers
        },
        {
          name: 'Complete current evolution',
          func: completeEvolution
        },
        {
          name: 'Gain all improvements at level 0',
          func: gainImprovs0
        },
        {
          name: 'Gain all improvements at max level',
          func: gainImprovsMax
        },
        {
          name: 'Complete current organ',
          func: completeOrgan 
        },
        {
          name: 'Clear AI',
          func: clearAI
        },
        {
          name: 'Spawn a cop',
          func: spawnCop
        },
        {
          name: 'Spawn a body',
          func: spawnBody
        },
        {
          name: 'Show area manager queue',
          func: showAreaManagerQueue
        },
        {
          name: 'Set area alertness to 100',
          func: setMaxAlertness
        },
        {
          name: 'Unlock timeline',
          func: unlockTimeline 
        },
        {
          name: 'Open timeline',
          func: openTimeline 
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


// remove energy spend without a host
  function removeEnergySpend()
    {
      game.player.vars.areaEnergyPerTurn = 0;
      game.log('Energy per turn removed.');
    }


// toggle LOS 
  function toggleLOS()
    {
      game.player.vars.losEnabled = !game.player.vars.losEnabled;
      area.updateVisibility();
      game.log('LOS checks for player toggled.');
    }


// complete current improvement
  function completeEvolution()
    {
//      game.player.energy += 10000;
      game.player.evolutionManager.turn(2000);
      game.player.energy = 100;
    }


// gain all improvements at level 0 
  function gainImprovs0()
    {
      for (imp in ConstEvolution.improvements)
        if (!game.player.evolutionManager.isKnown(imp.id))
          game.player.evolutionManager.addImprov(imp.id);
      game.player.evolutionManager.state = 2;
      game.log('All evolution improvements gained at level 0');
    }


// gain all improvements at level 0 
  function gainImprovsMax()
    {
      gainImprovs0();
  
      for (imp in game.player.evolutionManager.getList())
        {
          imp.level = 3;
          imp.ep = ConstEvolution.epCostImprovement[imp.level];
        }
      game.player.evolutionManager.state = 2;
      game.log('All evolution improvements gained at max level');
    }


// complete current organ
  function completeOrgan()
    {
      if (game.player.state != PLR_STATE_HOST)
        return;

      game.player.host.organs.debugCompleteCurrent();
    }


// clear all AI in area
  function clearAI()
    {
      for (ai in area.getAIinRadius(area.player.x, area.player.y, 100, false))
        if (ai != game.player.host)
          area.removeAI(ai);
    }


// spawn and control host
  function gainHost()
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


// spawn and control host (plus open stuff up)
  function gainHostAdvanced()
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
      game.player.evolutionManager.addImprov(IMP_BRAIN_PROBE);
      var imp = game.player.evolutionManager.getImprov(IMP_BRAIN_PROBE);
      imp.level = 2;
    }


// spawn a cop
  function spawnCop()
    {
      var ai = new PoliceAI(game, area.player.x, area.player.y);
      ai.inventory.clear();
      ai.inventory.addID('baton');
      ai.skills.addID(SKILL_BATON, 50 + Std.random(25));
      area.addAI(ai);
    }


// spawn a body
  function spawnBody()
    {
//      var o = area.createObject(area.player.x, area.player.y, 'body', 'civilian');
      var o = new BodyObject(game, area.player.x, area.player.y, 'civilian');
      o.isHumanBody = true;
      o.organPoints = 10;
//      o.setDecay(1);

      area.debugShowObjects();
    }


// show area manager queue
  function showAreaManagerQueue()
    {
      game.area.manager.debugShowQueue();
    }


// set max area alertness
  function setMaxAlertness()
    {
      game.area.debugSetMaxAlertness();
    }


// enter sewers (region mode)
  function enterSewers()
    {
      game.scene.setState(HUDSTATE_DEFAULT);
      game.setLocation(Game.LOCATION_REGION);
    }


// unlock event timeline
  function unlockTimeline()
    {
      game.log('Timeline unlocked.');
      game.player.skills.increase(KNOW_SOCIETY, 1);
      game.player.skills.increase(KNOW_SOCIETY, 24);
    }


// open event timeline
  function openTimeline()
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
}
