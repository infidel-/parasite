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
  public static function skill(p: {
      var id: _Skill; // skill id
      var level: Float; // skill level

      // roll bonuses
      @:optional var bonuses: Array<{ name: String, val: Float }>;
    }): Bool
    {
      var roll = Std.random(100);

      // calc level with bonuses
      var chance = p.level;
      if (p.bonuses != null)
        for (b in p.bonuses)
          chance += b.val;
      if (chance > 99)
        chance = 99;
      if (chance < 1)
        chance = 1;

      if (game.config.extendedMode)
        {
          var s = new StringBuf();
          s.add('Skill ');
          s.add(SkillsConst.getInfo(p.id).name);
          s.add(': ');
          s.add(chance);
          s.add('% ');
          if (p.bonuses != null && p.bonuses.length > 0)
            {
              s.add('[');
              s.add(p.level);
              s.add('%, ');
              for (i in 0...p.bonuses.length)
                {
                  var b = p.bonuses[i];
                  s.add(b.name);
                  s.add(' ');
                  if (b.val > 0)
                    s.add('+');
                  s.add(b.val);
                  s.add('%');
                  if (i < p.bonuses.length - 1)
                    s.add(', ');
                }
              s.add('] ');
            }
          s.add('(roll: ');
          s.add(roll);
          s.add(') = ');
          if (roll <= chance)
            s.add('success');
          else s.add('fail');
          s.add('.');

          game.debug(s.toString());
        }

      return (roll <= chance);
    }


// roll an opposing test and return result
  public static function opposingAttr(attr: Float, attr2: Float,
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

