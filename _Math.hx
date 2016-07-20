// all formulas in one place

import game.*;
import const.*;

class _Math
{
  public static var game: Game; // game link (set on init)

// evolution points per turn
  public static inline function epPerTurn()
    {
      return 10;
    }


// evolution energy per turn
  public static inline function evolutionEnergyPerTurn()
    {
      return (game.location == LOCATION_AREA && game.area.isHabitat) ?
        game.player.vars.evolutionEnergyPerTurnMicrohabitat :
        game.player.vars.evolutionEnergyPerTurn;
    }


// roll a skill and return result
  public static inline function skill(level: Float, skill: _Skill): Bool
    {
      var roll = Std.random(100);
      if (game.config.extendedMode)
        game.debug(
          'Skill ' + SkillsConst.getInfo(skill).name + ': ' +
          level + '% (roll: ' + roll + ') = ' +
          (roll <= level ? 'success' : 'fail') + '.');

      return (roll <= level);
    }


// roll an opposing test and return result
  public static inline function opposingAttr(attr: Float, attr2: Float,
      name: String): Bool
    {
      var chance = 50 + 5 * (attr - attr2);
      if (chance > 99)
        chance = 99;
      if (chance < 1)
        chance = 1;
      var roll = Std.random(100);

      if (game.config.extendedMode)
        game.debug(
          'Opposing attribute check for ' + name + ': ' +
          attr + ' vs ' + attr2 + ', ' + chance + '% (roll: ' + roll + ') = ' +
          (roll <= chance ? 'success' : 'fail') + '.');

      return (roll <= chance);
    }
}

