// object that can be picked up (note, cell phone, etc)
// intended to be inherited

package objects;

import game.Game;

class Pickup extends AreaObject
{
  public function new(g: Game, vaid: Int, vx: Int, vy: Int)
    {
      super(g, vaid, vx, vy);
//      init();
//      initPost(false);
    }

// init object before loading/post creation
  public override function init()
    {
      super.init();
      type = 'pickup';
      name = 'pickup';
    }

// called after load or creation
  public override function initPost(onLoad: Bool)
    {
      super.initPost(onLoad);
      // NOTE: do not create entities here!
    }


// update actions
  override function updateActionList()
    {
      if (game.player.state != PLR_STATE_HOST ||
          !game.player.host.isHuman ||
          game.player.host.inventory.length() >=
          game.player.host.maxItems)
        return;

      var itemName = (game.player.knowsItem(item.info.id) ?
        item.name : item.info.unknown);
      game.ui.hud.addAction({
        id: 'get',
        type: ACTION_OBJECT,
        name: 'Get ' + Const.col('inventory-item', itemName),
        energy: 5,
        isAgreeable: true,
        obj: this
      });
    }

// is this item known to player?
  public override function known(): Bool
    {
      return game.player.knowsItem(item.id);
    }

// ACTION: action handling
  override function onAction(action: _PlayerAction): Bool
    {
      // get stuff from body
      if (action.id == 'get')
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
