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
/*
        {
          name: "Remove energy spend without a host",
          func: removeEnergySpend
        },
*/
        ];
    }


// call an action
  public function action(idx: Int)
    {
      var a = actions[idx];
      Reflect.callMethod(this, a.func, []);
    }


/*
// remove energy spend without a host
  function removeEnergySpend()
    {
      game.player.vars.energyPerTurn = 0;
      game.log('Energy per turn removed.');
    }
*/
}
