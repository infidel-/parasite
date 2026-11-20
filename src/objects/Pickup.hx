// object that can be picked up (note, cell phone, etc)
// intended to be inherited

package objects;

import l10n.Loc;

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
      name = N('pickup');
    }

// called after load or creation
  public override function initPost(onLoad: Bool)
    {
      super.initPost(onLoad);
      // NOTE: do not create entities here!
    }


// key the 3D view looks a glb prop up by: WHAT the item is and not which atlas frame it was given.
// everything else on the ground stays 'pickup' and so keeps its sprite — see
// render.world.ObjModels.modelFor, which answers null for a key with no row
  public override function getModelKey(): String
    {
      if (item != null &&
          item.id == 'shipPart')
        return 'pickup_shipPart';
      return type;
    }

// can the player pick this up right now? (human host with inventory space)
  public function canGet(): Bool
    {
      return game.player.state == PLR_STATE_HOST &&
        game.player.host.isHuman &&
        game.player.host.inventory.length() < game.player.host.maxItems;
    }

// item-pickup action (grouped into the tile's Get action / pickup submenu by PlayerArea)
  public override function getItemActions(): Array<_PlayerAction>
    {
      if (!canGet())
        return [];

      return [{
        id: 'get',
        type: ACTION_OBJECT,
        name: T('Get {item}', { item: Loc.colored('inventory-item', item) }),
        energy: 5,
        isAgreeable: true,
        obj: this
      }];
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
          game.player.log(T('You pick {item:the} up.', { item: Loc.colored('inventory-item', item) }));
          game.player.host.inventory.add(item);
          game.area.removeObject(this);
          item.info.onPickup(item);

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
