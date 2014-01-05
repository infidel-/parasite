// debug actions

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
          name: 'Gain all improvements at level 0',
          func: gainImprovs0
        },
        {
          name: 'Gain all improvements at max level',
          func: gainImprovsMax
        },
        {
          name: 'Spawn a cop',
          func: spawnCop
        },
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


// spawn a cop
  function spawnCop()
    {
      var ai = new PoliceAI(game, game.player.x, game.player.y);
      game.area.addAI(ai);
    }


// gain all improvements at level 0 
  function gainImprovs0()
    {
      for (imp in EvolutionConst.improvements)
        if (!game.player.evolutionManager.isKnown(imp.id))
          game.player.evolutionManager.addImprov(imp.id);
    }


// gain all improvements at level 0 
  function gainImprovsMax()
    {
      gainImprovs0();
  
      for (imp in game.player.evolutionManager.getList())
        {
          imp.level = 3;
          imp.ep = EvolutionConst.epCostImprovement[imp.level];
        }
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
      var ai = new HumanAI(game, game.player.x, game.player.y);
      game.area.addAI(ai);
      game.player.actionDebugAttachAndInvade(ai);
      game.player.hostControl = 100;

      // give weapon
      ai.inventory.addID('pistol');
      ai.skills.addID('pistol', 25 + Std.random(25));
    }
}
