// special event object

package objects;

import game.Game;
import game.Player;

class EventObject extends AreaObject
{
  public var eventAction: _PlayerAction; // available action
  public var eventOnAction: Game -> Player -> String -> Void; // action handler

  public function new(g: Game, vx: Int, vy: Int, ?addToCurrent: Bool = true)
    {
      super(g, vx, vy, addToCurrent);

      type = 'event_object';
      name = 'event object';
      isStatic = true;

      createEntity(game.scene.entityAtlas
        [Const.FRAME_EVENT_OBJECT][Const.ROW_OBJECT]);
    }


// update actions
  override function updateActionsList()
    {
      addActionFull(eventAction);
    }


// handle special action
  override function onAction(id: String): Bool
    {
      eventOnAction(game, game.player, id);

      return true;
    }
}
