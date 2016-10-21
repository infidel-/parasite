// habitat-related things

package game;

import objects.*;

class Habitat
{
// put biomineral in habitat
// called from organ actions
  public static function putBiomineral(game: Game, player: Player): Bool
    {
      // only in habitat
      if (!game.area.isHabitat)
        {
          game.log('This action only works in habitat.', COLOR_HINT);
          return false;
        }

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

      return true;
    }
}
