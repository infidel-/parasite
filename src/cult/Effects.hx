// manages active cult effects
package cult;

import game.Game;

class Effects extends _SaveObject
{
  static var _ignoredFields = [ 'game', 'cult' ];
  public var game: Game;
  public var cult: Cult;
  var list: Array<Effect>;

// creates effects manager
  public function new(game: Game, cult: Cult)
    {
      this.game = game;
      this.cult = cult;
      list = [];
      init();
      initPost(false);
    }

// sets default state
  public function init()
    {}

// runs after creation or load
  public function initPost(onLoad: Bool)
    {
      if (list == null)
        list = [];
    }

// adds new effect or refreshes existing one
  public function add(effect: Effect)
    {
      var existing = get(effect.type);
      if (!effect.allowMultiple)
        {
          for (old in existing)
            {
              old.onRemove(cult);
              list.remove(old);
            }
        }

      list.push(effect);
      effect.onAdd(cult);
      cult.recalc();
    }

// checks if specific effect is active
  public function has(type: _CultEffectType): Bool
    {
      for (effect in list)
        if (effect.type == type)
          return true;
      return false;
    }

// returns list of effects by type
  public function get(type: _CultEffectType): Array<Effect>
    {
      var results: Array<Effect> = [];
      for (effect in list)
        if (effect.type == type)
          results.push(effect);
      return results;
    }

// advances all effects by provided time
  public function turn()
    {
      var time = 1;
      var expired: Array<Effect> = [];
      for (effect in list)
        {
          effect.turn(cult, time);
          effect.turns -= time;
          if (effect.turns <= 0)
            expired.push(effect);
        }
      if (expired.length == 0)
        return;

      for (effect in expired)
        {
          list.remove(effect);
          effect.onRemove(cult);
        }
      cult.recalc();
    }

// returns copy of all active effects
  public function iterator(): Iterator<Effect>
    {
      return list.iterator();
    }
}
