// AI effects - paralysis, bleed, panic, etc

package game;

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
  public function add(eff: _AIEffect)
    {
      _list.add({
        type: eff.type,
        points: eff.points,
        isTimer: (eff.isTimer == true)
      });
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
  public function decrease(type: _AIEffectType, pts: Int): Bool
    {
      var e = get(type);
      e.points -= pts;
      if (e.points <= 0)
        {
          _list.remove(e);
          return true;
        }

      return false;
    }


// list iterator
  public function iterator(): Iterator<Effect>
    {
      return _list.iterator();
    }


// passage of time
  public function turn(time: Int)
    {
      // rot timer effects
      for (e in _list)
        {
          if (!e.isTimer)
            continue;

          e.points -= time;
          if (e.points <= 0)
            _list.remove(e);
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


@:structInit class Effect extends _SaveObject
{
  public var type: _AIEffectType; // effect type
  public var points: Int; // current effect strength
  public var isTimer: Bool; // is this a timer?

  public function new(type, points, isTimer)
    {
      this.type = type;
      this.points = points;
      this.isTimer = isTimer;
      init();
      initPost(false);
    }

// init object before loading/post creation
  public function init()
    {
    }

// called after load or creation
  public function initPost(onLoad: Bool)
    {
    }
}
