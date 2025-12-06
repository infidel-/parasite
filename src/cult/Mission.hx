// base class for cult missions (missio/clavis)
package cult;

import game.Game;
import _MissionType;
import ai.AI;

class Mission extends _SaveObject
{
  static var _ignoredFields = [ 'game' ];
  public static var _maxID: Int = 0; // current max ID
  public var game: Game;
  public var id: Int;
  public var name: String;
  public var note: String;
  public var type: _MissionType;
  public var x: Int; // regional position
  public var y: Int; // regional position
  public var ordeal(get, never): Ordeal; // reference to parent ordeal
  public var isCompleted: Bool; // mission completion status

  public function new(g: Game)
    {
      game = g;
// will be called by sub-classes
//      init();
//      initPost(false);
    }

// init object before loading/post creation
  public function init()
    {
      id = (_maxID++);
      name = '';
      note = '';
      x = 0;
      y = 0;
      isCompleted = false;
    }

// called after load or creation
  public function initPost(onLoad: Bool)
    {}

// get custom name for display
  public function customName(): String
    {
      return name;
    }

// get colored name for display
  public function coloredName(): String
    {
      return Const.col('profane-ordeal', customName());
    }

// called when mission is successfully completed
  public function success()
    {
      onSuccess(); // call subclass hook
      isCompleted = true; // mark mission as completed
      game.logsg('Mission completed: ' + coloredName() + '.');
      if (ordeal != null)
        ordeal.check(); // check if ordeal is complete
    }

// turn hook for mission processing
  public function turn()
    {}

// hook for when mission succeeds
  public function onSuccess()
    {}

// hook for when mission target dies
  public function onMissionDeath(ai: AI)
    {}

  // get ordeal property
  function get_ordeal(): Ordeal
    {
      for (o in game.cults[0].ordeals.list)
        for (m in o.missions)
          if (m.id == id)
            return o;
      return null;
    }
}
