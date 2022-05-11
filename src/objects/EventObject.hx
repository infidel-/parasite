// special event object

package objects;

import game.Game;
import game.Player;

class EventObject extends AreaObject
{
  public var eventAction: _PlayerAction; // available action
  public var eventOnAction: Game -> Player -> String -> Void; // action handler

  public function new(g: Game, vaid: Int, vx: Int, vy: Int)
    {
      super(g, vaid, vx, vy);

      init();
      initPost(false);
    }

// init object before loading/post creation
  public override function init()
    {
      super.init();
      type = 'event_object';
      name = 'event object';
      isStatic = true;
      imageCol = Const.FRAME_EVENT_OBJECT;
    }

// called after load or creation
  public override function initPost(onLoad: Bool)
    {
      super.initPost(onLoad);
    }


// update actions
  override function updateActionList()
    {
      game.ui.hud.addAction(eventAction);
    }


// handle special action
  override function onAction(id: String): Bool
    {
      eventOnAction(game, game.player, id);

      return true;
    }
}
