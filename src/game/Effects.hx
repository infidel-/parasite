// AI effects - paralysis, bleed, panic, etc

package game;

import ai.AI;
import ai.AIData;

class Effects extends _SaveObject
{
  static var _ignoredFields = [ 'ai' ];
  var game: Game;
  var ai: AIData; // parent AI link
  var _list: List<Effect>; // list of effects

  public function new(vgame: Game, vai: AIData)
    {
      ai = vai;
      game = vgame;
      _list = new List<Effect>();
    }


// add new effect
  public function add(effect: Effect)
    {
      var existing = get(effect.type);
      if (existing != null)
        {
          existing.points += effect.points;
          if (effect.isTimer && !existing.isTimer)
            existing.isTimer = true;
          return;
        }

      _list.add(effect);
    }


// does this AI has this effect?
  public function has(type: _AIEffectType): Bool
    {
      for (e in _list)
        if (e.type == type)
          return true;

      return false;
    }


// get effect by type
  public function get(type: _AIEffectType): Effect
    {
      for (e in _list)
        if (e.type == type)
          return e;

      return null;
    }


// decrease effect lifetime and remove it if needed
// note: returns true if effect is removed
  public function decrease(type: _AIEffectType, pts: Int, aiRef: AI): Bool
    {
      var e = get(type);
      e.points -= pts;
      if (e.points <= 0)
        {
          _list.remove(e);
          e.onRemove(aiRef);
          return true;
        }

      return false;
    }


// list iterator
  public function iterator(): Iterator<Effect>
    {
      return _list.iterator();
    }


// returns all damage modifiers from active effects for given weapon
  public function damageMods(weapon: WeaponInfo): Array<_DamageBonus>
    {
      var mods = [];
      for (effect in _list)
        {
          var effectMods = effect.damageMods(weapon);
          if (effectMods == null || effectMods.length == 0)
            continue;
          for (mod in effectMods)
            mods.push(mod);
        }
      return mods;
    }


// passage of time
  public function turn(aiRef: AI, time: Int)
    {
      // rot timer effects
      for (e in _list)
        {
          e.turn(aiRef, time);

          if (!e.isTimer)
            continue;

          e.points -= time;
          if (e.points <= 0)
            {
              _list.remove(e);
              e.onRemove(aiRef);
            }
        }
    }


  public function toString(): String
    {
      var tmp = [];
      for (e in _list)
        tmp.push(e.type + ' pts:' + e.points);
      return tmp.join(', ');
    }
}
