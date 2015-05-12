// special event object 

package objects;

import game.Game;
import game.Player;

class EventObject extends AreaObject
{
  public var eventOnAction: Game -> Player -> String -> Void; // action handler

  public function new(g: Game, vx: Int, vy: Int)
    {
      super(g, vx, vy);

      type = 'event_object';
      name = 'event object';
      isStatic = true;

      createEntity(Const.ROW_OBJECT, Const.FRAME_EVENT_OBJECT);
    }


// handle special action 
  override function onAction(id: String)
    {
      eventOnAction(game, game.player, id);
    }
}
