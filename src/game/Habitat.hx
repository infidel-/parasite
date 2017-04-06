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
  public var energyUsed: Int; // used energy
  public var hostEnergyRestored: Int; // restored energy per turn (host)
  public var parasiteEnergyRestored: Int; // restored energy per turn (parasite)
  public var parasiteHealthRestored: Int; // restored health per turn (parasite)
  public var evolutionBonus: Int; // biomineral evolution bonus (max)


  public function new(g: Game, a: AreaGame)
    {
      game = g;
      player = game.player;
      area = a;

      energy = 0;
      energyUsed = 0;
      hostEnergyRestored = 0;
      parasiteEnergyRestored = 0;
      parasiteHealthRestored = 0;
      evolutionBonus = 0;
    }


// put biomineral in habitat
// called from organ actions
  public function putBiomineral(): Bool
    {
      // check for free space
      if (game.area.hasObjectAt(player.host.x, player.host.y))
        {
          game.log('Not enough free space.', COLOR_HINT);
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

      // update habitat stats
      update();

      return true;
    }


// put assimilation cavity in habitat
// called from organ actions
  public function putAssimilation(): Bool
    {
      // check for free space
      if (game.area.hasObjectAt(player.host.x, player.host.y))
        {
          game.log('Not enough free space.', COLOR_HINT);
          return false;
        }

      // check for energy
      if (energyUsed >= energy)
        {
          game.log('Not enough energy in habitat.', COLOR_HINT);
          return false;
        }

      // complete goals
      game.goals.complete(GOAL_PUT_ASSIMILATION);

      // spawn object
      var ai = player.host;
      var level = ai.organs.getLevel(IMP_ASSIMILATION);
      var o = new AssimilationCavity(game, ai.x, ai.y, level);

      // remove and kill host
      game.playerArea.onDetach();
      game.area.removeAI(ai);

      game.log('Assimilation cavity completed.', COLOR_AREA);

      game.area.updateVisibility();

      // update habitat stats
      update();

      return true;
    }


// update habitat stats
  public function update()
    {
      // clear vars
      energy = 0;
      energyUsed = 0;
      hostEnergyRestored = 0;
      parasiteEnergyRestored = 0;
      parasiteHealthRestored = 0;
      evolutionBonus = 0;

      // recalc vars
      for (o in area.getObjects())
        // biomineral - give energy
        if (o.name == 'biomineral')
          {
            var b: Biomineral = cast o;
            var info = EvolutionConst.getParams(IMP_BIOMINERAL, b.level);
            energy += info.energy;
            if (info.evolutionBonus > evolutionBonus)
              {
                evolutionBonus = info.evolutionBonus;
                hostEnergyRestored = info.hostEnergyRestored;
                parasiteEnergyRestored = info.parasiteEnergyRestored;
                parasiteHealthRestored = info.parasiteHealthRestored;
              }
          }

        // each habitat object uses energy
        else if (o.type == 'habitat')
          energyUsed++;

      // no free energy, disable energy and health restoration
      if (energyUsed >= energy)
        {
          hostEnergyRestored = 0;
          parasiteEnergyRestored = 0;
          parasiteHealthRestored = 0;
        }

      Const.debugObject(this);
    }
}
