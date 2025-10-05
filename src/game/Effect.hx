// ai effect

package game;

import ai.AI;

class Effect extends _SaveObject
{
  public var game: Game; // game state link
  public var type: _AIEffectType; // effect type
  public var points: Int; // current effect strength
  public var isTimer: Bool; // is this a timer?
  public var name: String; // effect display name
  public var isHidden: Bool; // should this effect be hidden from UI

// creates base effect instance
  public function new(game: Game, type: _AIEffectType, points: Int, isTimer: Bool)
    {
      this.game = game;
      this.type = type;
      this.points = points;
      this.isTimer = isTimer;
    }

// init object before loading/post creation
  public function init()
    {
      name = '';
      isHidden = false;
    }

// called after load or creation
  public function initPost(onLoad: Bool)
    {
    }

// runs effect-specific turn logic
  public function turn(ai: AI, time: Int)
    {
    }

// runs when effect is removed from AI
  public function onRemove(ai: AI)
    {
    }
}
