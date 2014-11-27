// debug actions (region mode)

class DebugRegion
{
  var game: Game;
  var region: Region;

  public var actions: Array<{ name: String, func: Dynamic }>;

  public function new(g: Game, r: Region)
    {
      game = g;
      region = r;

      actions = [
        {
          name: "Remove energy spend per turn and movement cost",
          func: removeEnergySpend
        },
        {
          name: "Make region known",
          func: makeRegionKnown 
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
      game.player.vars.areaEnergyPerTurn = 0;
      game.player.vars.regionMoveEnergy = 0;
      game.log('Energy per turn and movement cost removed.');
    }


  function makeRegionKnown()
    {
      for (a in game.region.getRegion())
        a.isKnown = true;
      game.region.updateVisibility();
    }
}
