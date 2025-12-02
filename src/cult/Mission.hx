// base class for cult missions (missio/clavis)
package cult;

import game.Game;
import _MissionType;

class Mission extends _SaveObject
{
  static var _ignoredFields = [ 'game' ];
  public var game: Game;
  public var name: String;
  public var note: String;
  public var type: _MissionType;

  public function new(g: Game)
    {
      game = g;
      init();
      initPost(false);
    }

// init object before loading/post creation
  public function init()
    {
      name = '';
      note = '';
    }

// called after load or creation
  public function initPost(onLoad: Bool)
    {}

// get custom name for display
  public function customName(): String
    {
      return name;
    }
}
