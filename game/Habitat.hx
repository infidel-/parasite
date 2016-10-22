// habitat-related things

package game;

import objects.*;
import const.*;

class Habitat
{
  var game: Game;
  var player: Player;
  var area: AreaGame;

  // calculated stats
  public var energy: Int; // produced energy
  public var evolutionBonus: Int; // biomineral evolution bonus (max)


  public function new(g: Game, a: AreaGame)
    {
      game = g;
      player = game.player;
      area = a;

      energy = 0;
      evolutionBonus = 0;
    }


// put biomineral in habitat
// called from organ actions
  public function putBiomineral(): Bool
    {
      // complete goals
      game.goals.complete(GOAL_PUT_BIOMINERAL);

      // spawn object
      var ai = player.host;
      var level = ai.organs.getLevel(IMP_BIOMINERAL);
      var o = new Biomineral(game, ai.x, ai.y, level);

      // remove and kill host
      game.playerArea.onDetach();
      game.area.removeAI(ai);

      game.log('Biomineral formation completed.', COLOR_AREA);

      game.area.updateVisibility();

      // update habitat stats
      update();

      return true;
    }


// update habitat stats
  public function update()
    {
      energy = 0;
      evolutionBonus = 0;

      for (o in area.getObjects())
        // biomineral - give energy
        if (o.name == 'biomineral')
          {
            var b: Biomineral = untyped o;
            var info = EvolutionConst.getParams(IMP_BIOMINERAL, b.level);
            energy += info.energy;
            if (info.evolutionBonus > evolutionBonus)
              evolutionBonus = info.evolutionBonus;
          }

      Const.debugObject(this);
    }
}
