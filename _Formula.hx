// all formulas in one place

import game.*;

class _Formula
{
// evolution points per turn
  public static inline function epPerTurn(game: Game)
    {
      return 10;
    }


// evolution energy per turn
  public static inline function evolutionEnergyPerTurn(game: Game)
    {
      return (game.location == LOCATION_AREA && game.area.isHabitat) ?
        game.player.vars.evolutionEnergyPerTurnMicrohabitat :
        game.player.vars.evolutionEnergyPerTurn;
    }
}
