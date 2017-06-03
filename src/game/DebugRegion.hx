// debug actions (region mode)

package game;

class DebugRegion
{
  var game: Game;

  public var actions: Array<{ name: String, func: Void -> Void }>;

  public function new(g: Game)
    {
      game = g;

      actions = [
        {
          name: "Remove energy spend per turn and movement cost",
          func: function()
            {
              game.player.vars.areaEnergyPerTurn = 0;
              game.player.vars.regionEnergyPerTurn = 0;
              game.log('Energy per turn and movement cost removed.');
            }
        },
        {
          name: "Make region known",
          func: function()
            {
              for (a in game.region)
                a.isKnown = true;
              game.region.updateVisibility();
              game.scene.region.updateIcons();
            }
        },
        ];
    }


// call an action
  public function action(idx: Int)
    {
      var a = actions[idx];
      Reflect.callMethod(this, a.func, []);
    }
}
