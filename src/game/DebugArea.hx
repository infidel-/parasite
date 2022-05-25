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
