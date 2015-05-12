// body object (human, animal, etc)

package objects;

import game.Game;
import game.Inventory;

class BodyObject extends AreaObject
{
  public var inventory: Inventory; // inventory (copied from AI)

  public var isSearched: Bool; // is this body searched?
  public var isHumanBody: Bool; // is this a human body?
  public var organPoints: Int; // amount of organs on this body

  public function new(g: Game, vx: Int, vy: Int, parentType: String)
    {
      super(g, vx, vy);

      inventory = new Inventory(g);
      type = 'body';
      name = 'body';
      isHumanBody = false;
      isSearched = false;
      organPoints = 0;

      createEntityByType(parentType);
    }


// update actions
  override function updateActionsList()
    {
      if (game.player.state != PLR_STATE_HOST)
        return;

      // animals don't have stuff on them
      if (!isSearched && isHumanBody)
        addAction('searchBody', 'Search Body', 10);

      if (isSearched)
        for (item in inventory)
          {
            var name = (game.player.knowsItem(item.id) ? 
              item.name : item.info.unknown);
            addAction('get.' + item.id, 'Get ' + name, 5);
          }
    }


// ACTION: action handling 
  override function onAction(id: String)
    {
      // search body for stuff
      if (id == 'searchBody')
        searchAction();

      // get stuff from body
      else if (id.substr(0, 4) == 'get.')
        getAction(id.substr(4));
    }


// ACTION: get stuff
  function getAction(id: String)
    {
      for (item in inventory)
        if (item.id == id)
          {
            var tmpname = (game.player.knowsItem(item.info.id) ? 
              item.name : item.info.unknown);
            game.player.log('You pick the ' + tmpname + ' up.');
            game.player.host.inventory.add(item);
            inventory.remove(id);
            break;
          }
    }


// ACTION: search body
  function searchAction()
    {
      if (Std.random(100) < game.player.hostControl)
        game.log("Your host resists your command.");

      game.log("You've thoroughly searched the body.");
      isSearched = true;
    }


// TURN: despawn bodies and generate area events
  public override function turn()
    {
      // not enough time has passed
      if (game.turns - creationTime < DESPAWN_TURNS)
        return;

      // notify world about body discovery by authorities
      game.managerRegion.onBodyDiscovered(game.area, organPoints);

      game.area.removeObject(this);
    }


  static var DESPAWN_TURNS = 20; // turns until body is despawned (picked up by law etc)
}
