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


// roll damage with bonuses and return result
  public static function damage(p: {
      var name: String;
      @:optional var chance: Float; // chance of damage
      @:optional var min: Int; // min damage
      @:optional var max: Int; // max damage
      @:optional var val: Int; // fixed value (alternative)

      // damage mods
      @:optional var mods: Array<_DamageBonus>;
    }): Int
    {
      var base = (p.val != null ? p.val : Const.roll(p.min, p.max));
      var damage = base;

      var s = null;
      if (game.config.extendedInfo)
        {
          s = new StringBuf();
          s.add('Damage ' + p.name + ': ');
          if (p.val != null)
            s.add(base);
          else s.add(p.min + '...' + p.max + ' (' + base + ')');
        }

      if (p.mods != null && p.mods.length > 0)
        {
          if (game.config.extendedInfo)
            s.add(' + [{ ');
          for (i in 0...p.mods.length)
            {
              var b = p.mods[i];
              var roll = 0;
              var ok = true;
              var val = (b.val != null ? b.val : Const.roll(b.min, b.max));
              if (b.chance != null)
                {
                  roll = Std.random(100);
                  if (roll > b.chance)
                    ok = false;
                }

              if (ok)
                damage += val;

              if (game.config.extendedInfo)
                {
                  s.add(b.name + ' ');
                  if (b.val > 0 || b.min > 0 || b.max > 0)
                    s.add('+');
                  if (b.val != null)
                    s.add(b.val);
                  else s.add(b.min + '...' + b.max + ' (' +
                    (val > 0 ? '+' : '') + val + ')');
                  if (b.chance != null)
                    s.add(', ' + b.chance + '% (roll: ' + roll + '), ' +
                      (ok ? 'success' : 'fail'));

                  if (i < p.mods.length - 1)
                    s.add(' }, { ');
                }
            }
          s.add(' }]');
        }

      // clamp value
      if (damage < 0)
        damage = 0;

      if (p.chance != null)
        {
          var roll = Std.random(100);
          if (game.config.extendedInfo)
            s.add(', ' + p.chance + '% (roll: ' + roll + '), ' +
              (roll <= p.chance ? 'success' : 'fail'));

          if (roll > p.chance)
            damage = 0;
        }

      if (game.config.extendedInfo)
        {
          s.add(' = ' + damage + '.');
          game.info(s.toString());
        }

      return damage;
    }


// roll a skill and return result
  public static function skill(p: {
      var id: _Skill; // skill id
      var level: Float; // skill level

      // roll mods
      @:optional var mods: Array<{ name: String, val: Float }>;
    }): Bool
    {
      var roll = Std.random(100);

      // calc level with mods
      var chance = p.level;
      if (p.mods != null)
        for (b in p.mods)
          chance += b.val;
      if (chance > 99)
        chance = 99;
      if (chance < 1)
        chance = 1;

      if (game.config.extendedInfo)
        {
          var s = new StringBuf();
          s.add('Skill ');
          s.add(SkillsConst.getInfo(p.id).name);
          s.add(': ');
          s.add(chance);
          s.add('% ');
          if (p.mods != null && p.mods.length > 0)
            {
              s.add('[');
              s.add(p.level);
              s.add('%, ');
              for (i in 0...p.mods.length)
                {
                  var b = p.mods[i];
                  s.add(b.name);
                  s.add(' ');
                  if (b.val > 0)
                    s.add('+');
                  s.add(b.val);
                  s.add('%');
                  if (i < p.mods.length - 1)
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

          game.info(s.toString());
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

      game.info(
        'Opposing attribute check for ' + name + ': ' +
        attr + ' vs ' + attr2 + ', ' + chance + '% (roll: ' + roll + ') = ' +
        (roll <= chance ? 'success' : 'fail') + '.');

      return (roll <= chance);
    }
}


typedef _DamageBonus = {
  var name: String;
  @:optional var chance: Float; // chance of damage
  @:optional var min: Int; // min damage
  @:optional var max: Int; // max damage
  @:optional var val: Int; // fixed value (alternative)
}
