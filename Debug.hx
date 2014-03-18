// debug actions

import ai.*;
import objects.*;

class Debug
{
  var game: Game;

  public var actions: Array<{ name: String, func: Dynamic }>;

  public function new(g: Game)
    {
      game = g;

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
          name: 'Toggle LOS',
          func: toggleLOS
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
        }
        ];
    }


// call an action
  public function action(idx: Int)
    {
      var a = actions[idx];
      Reflect.callMethod(this, a.func, []);
    }


// remove energy spend without a host
  function removeEnergySpend()
    {
      game.player.vars.energyPerTurn = 0;
      game.log('Energy per turn removed.');
    }


// toggle LOS 
  function toggleLOS()
    {
      game.player.vars.losEnabled = !game.player.vars.losEnabled;
      game.area.updateVisibility();
      game.log('LOS checks for player toggled.');
    }


// gain all improvements at level 0 
  function gainImprovs0()
    {
      for (imp in ConstEvolution.improvements)
        if (!game.player.evolutionManager.isKnown(imp.id))
          game.player.evolutionManager.addImprov(imp.id);
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
      game.log('All evolution improvements gained at max level');
    }


// clear all AI in area
  function clearAI()
    {
      for (ai in game.area.getAIinRadius(game.player.x, game.player.y, 100, false))
        if (ai != game.player.host)
          game.area.destroyAI(ai);
    }


// spawn and control host
  function gainHost()
    {
      if (game.player.state != Player.STATE_PARASITE)
        {
          trace('Must be in default state: ' + game.player.state);
          return;
        }

      // spawn AI, attach to it and invade
      var ai = new CivilianAI(game, game.player.x, game.player.y);
      game.area.addAI(ai);
      game.player.actionDebugAttachAndInvade(ai);
      game.player.hostControl = 100;

      // give weapon
      ai.inventory.addID('pistol');
      ai.skills.addID('pistol', 25 + Std.random(25));
//      ai.organs.addID('camouflageLayer');
      ai.organs.addID('decayAccel');
    }


// spawn a cop
  function spawnCop()
    {
      var ai = new PoliceAI(game, game.player.x, game.player.y);
      ai.inventory.clear();
      ai.inventory.addID('baton');
      ai.skills.addID('baton', 50 + Std.random(25));
      game.area.addAI(ai);
    }


// spawn a body
  function spawnBody()
    {
//      var o = game.area.createObject(game.player.x, game.player.y, 'body', 'civilian');
      var o = new BodyObject(game, game.player.x, game.player.y, 'civilian');
      o.isHumanBody = true;
      o.organPoints = 10;
//      o.setDecay(1);

      game.area.debugShowObjects();
    }


// show area manager queue
  function showAreaManagerQueue()
    {
      game.areaManager.debugShowQueue();
    }


// set max area alertness
  function setMaxAlertness()
    {
      game.world.area.alertness = 100;
    }
}
