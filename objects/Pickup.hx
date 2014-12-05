// object that can be picked up (note, cell phone, etc)
// intended to be inherited

package objects;


class Pickup extends AreaObject
{
  public var name: String; // linked item name

  public function new(g: Game, vx: Int, vy: Int)
    {
      super(g, vx, vy);

      type = 'pickup';
    }


// update actions
  override function updateActionsList()
    {
      if (game.player.state != PLR_STATE_HOST)
        return;

      var tmpname = (game.player.knowsItem(itemInfo.id) ? 
        name : itemInfo.unknown);
      addAction('get', 'Get ' + tmpname, 5);
    }


// ACTION: action handling 
  override function onAction(id: String)
    {
      // get stuff from body
      if (id == 'get')
        {
          game.player.host.inventory.addID(itemInfo.id, name);
          game.area.removeObject(this);
        }
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
