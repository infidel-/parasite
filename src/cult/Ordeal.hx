// ordeal base class for cult challenges
package cult;

import game.Game;
import cult.Cult;
import _CultPower;
import _OrdealType;

class Ordeal extends _SaveObject
{
  static var _ignoredFields = [ 'cult' ];
  public var game: Game;
  public var cult: Cult;
  public var name: String;
  public var members: Array<Int>; // cult members involved
  public var power: _CultPower;
  public var type: _OrdealType;

  public function new(g: Game, c: Cult)
    {
      game = g;
      cult = c;
      members = [];
      power = {
        combat: 0,
        media: 0,
        lawfare: 0,
        corporate: 0,
        political: 0,
        occult: 0,
        money: 0
      };

// will be called by sub-classes
//      init();
//      initPost(false);
    }

// init object before loading/post creation
  public function init()
    {
      type = ORDEAL_COMMUNAL;
    }

// called after load or creation
  public function initPost(onLoad: Bool)
    {}
}
