// object that can be picked up (note, cell phone, etc)
// intended to be inherited

package objects;

import game.Game;

class Pickup extends AreaObject
{
  public function new(g: Game, vx: Int, vy: Int)
    {
      super(g, vx, vy);

      type = 'pickup';
      name = 'pickup';

      // do not create entities here!
    }


// update actions
  override function updateActionList()
    {
      if (game.player.state != PLR_STATE_HOST)
        return;

      var itemName = (game.player.knowsItem(item.info.id) ?
        item.name : item.info.unknown);
      game.ui.hud.addAction({
        id: 'get',
        type: ACTION_OBJECT,
        name: 'Get ' + Const.col('inventory-item', itemName),
        energy: 5,
        obj: this
      });
    }


// ACTION: action handling
  override function onAction(id: String): Bool
    {
      // get stuff from body
      if (id == 'get')
        {
          var itemName = (game.player.knowsItem(item.info.id) ?
            item.name : item.info.unknown);
          game.player.log('You pick the ' + Const.col('inventory-item', itemName) + ' up.');
          game.player.host.inventory.add(item);
          game.area.removeObject(this);

          return true;
        }

      return false;
    }

/*
// TURN: despawn bodies and generate area events
  public override function turn()
    {
      // not enough time has passed
      if (game.turns - creationTime < DESPAWN_TURNS)
        return;

      // notify world about body discovery by authorities
      game.region.manager.onBodyDiscovered(game.area.getArea(), organPoints);

      game.area.removeObject(this);
    }


  static var DESPAWN_TURNS = 20; // turns until body is despawned (picked up by law etc)
*/
}
