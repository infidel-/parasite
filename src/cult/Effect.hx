// base class for cult effects
package cult;

import game.Game;

class Effect extends _SaveObject
{
  static var _ignoredFields = [ 'game' ];
  public var game: Game;
  public var type: _CultEffectType;
  public var turns: Int;
  public var name: String;
  public var isHidden: Bool;
  public var allowMultiple: Bool;

// creates base cult effect
  public function new(game: Game, type: _CultEffectType, turns: Int)
    {
      this.game = game;
      this.type = type;
      this.turns = turns;
      init();
      initPost(false);
    }

// sets default effect values
  public function init()
    {
      name = '';
      isHidden = false;
      allowMultiple = false;
    }

// runs after creation or load
  public function initPost(onLoad: Bool)
    {}

// runs when effect is added
  public function onAdd(cult: Cult)
    {}

// runs when effect is removed
  public function onRemove(cult: Cult)
    {}

// updates effect each turn
  public function turn(cult: Cult, time: Int)
    {}

// generic run hook called from where necessary
  public function run(cult: Cult)
    {}

// returns custom display name for effect
  public function customName(): String
    {
      return name;
    }

  // returns a short note with effect explanation
  // to be overridden by subclasses
  public function note(): String
    {
      return '';
    }
}
