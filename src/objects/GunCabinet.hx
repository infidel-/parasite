// a steel gun cabinet in a corp tower's security room, and the first CONTAINER the game has: a
// host opens it, searches it, and takes what it holds, one weapon rolled when the floor is built.
//
// BodyObject's loot flow on Door's open state. The loot lives in an Inventory and not in
// AreaObject.item, so a weapon from a mod that is no longer loaded drops out on its own
// (Inventory.initPost) instead of taking the cabinet with it (AreaGame.loadPost)

package objects;

import game.Game;
import game.Inventory;

class GunCabinet extends AreaObject
{
  // what a cabinet can hold, weighted. The security guard's own kit (ai.SecurityAI) and a bit above
  public static var LOOT: Array<{ id: String, weight: Int }> = [
    { id: 'pistol', weight: 35 },
    { id: 'stunner', weight: 20 },
    { id: 'baton', weight: 20 },
    { id: 'combatShotgun', weight: 15 },
    { id: 'assaultRifle', weight: 10 },
  ];

  public var inventory: Inventory; // what it holds
  public var isOpen: Bool; // is its door open?
  public var isSearched: Bool; // has a host gone through it?

  public function new(g: Game, vaid: Int, vx: Int, vy: Int)
    {
      super(g, vaid, vx, vy);
      init();
      inventory.addID(rollLoot());
      initPost(false);
    }

// init object before loading/post creation
  public override function init()
    {
      super.init();
      type = 'gunCabinet';
      name = 'gun cabinet';
      isStatic = true;
      imageRow = Const.CORP_CABINET[0].row;
      imageCol = 0;
      inventory = new Inventory(game);
      isOpen = false;
      isSearched = false;
    }

// called after load or creation
  public override function initPost(onLoad: Bool)
    {
      super.initPost(onLoad);
    }

// one weapon id off the weighted LOOT table
  static function rollLoot(): String
    {
      var total = 0;
      for (l in LOOT)
        total += l.weight;
      var roll = Std.random(total);
      for (l in LOOT)
        {
          roll -= l.weight;
          if (roll < 0)
            return l.id;
        }
      return LOOT[0].id;
    }

// a gun cabinet is plain to see; there is nothing to learn about it
  public override function known(): Bool
    { return true; }

// used from the cell beside it as well as its own
  public override function canActivateNear(): Bool
    { return true; }

// it stands in the wall's margin like the lockers beside it, so the floor in front stays walkable
// (its door swings through whoever stands there)
  public override function isWalkable(): Bool
    { return true; }

// the 3D prop, open or shut (render.world.ObjModels)
  public override function getModelKey(): String
    { return (isOpen ? 'gunCabinetOpen' : 'gunCabinet'); }

// shut, open, or open and gone through
  public override function getTooltipRows(): Array<objects.AreaObject.TooltipRow>
    {
      return [ {
        name: 'state',
        value: (!isOpen ? 'closed' : !isSearched ? 'open' :
          inventory.length() == 0 ? 'empty' : 'searched'),
      } ];
    }

// update actions: open, then search, then one Get per weapon. THE GETS ARE HERE AND NOT IN
// getItemActions, which PlayerArea only reads off the player's OWN cell, and a cabinet is used from
// beside it too
  override function updateActionList()
    {
      if (game.player.state != PLR_STATE_HOST)
        return;
      if (!isOpen)
        {
          game.ui.hud.addAction({
            id: 'openCabinet',
            type: ACTION_OBJECT,
            name: 'Open cabinet',
            energy: 5,
            obj: this
          });
          return;
        }
      if (!isSearched)
        {
          game.ui.hud.addAction({
            id: 'searchCabinet',
            type: ACTION_OBJECT,
            name: 'Search cabinet',
            energy: 10,
            obj: this
          });
          return;
        }
      for (item in inventory)
        {
          if (game.player.host.inventory.length() >=
              game.player.host.maxItems)
            break;
          var name = (game.player.knowsItem(item.id) ?
            item.name : item.info.unknown);
          game.ui.hud.addAction({
            id: 'get.' + item.id,
            type: ACTION_OBJECT,
            name: 'Get ' + Const.col('inventory-item', name),
            energy: 5,
            obj: this
          });
        }
    }

// ACTION: action handling
  override function onAction(action: _PlayerAction): Bool
    {
      if (action.id == 'openCabinet')
        openAction();
      else if (action.id == 'searchCabinet')
        searchAction();
      else if (action.id.substr(0, 4) == 'get.')
        getAction(action.id.substr(4));
      return true;
    }

// ACTION: open the door, and swap the 3D prop for the open one
  function openAction()
    {
      isOpen = true;
      game.log('You open the gun cabinet.');
      game.scene.sounds.play('door-metal-open1', {
        x: x,
        y: y,
        canDelay: true,
        always: true,
      });
      game.scene.updateObjects3D();
    }

// ACTION: go through it
  function searchAction()
    {
      isSearched = true;
      if (inventory.length() == 0)
        {
          game.log('The gun cabinet is empty.');
          return;
        }
      for (item in inventory)
        {
          var name = (game.player.knowsItem(item.id) ?
            item.name : item.info.unknown);
          game.log('You find ' + Const.col('inventory-item', name) + ' in the gun cabinet.');
        }
    }

// ACTION: take one weapon out
  function getAction(id: String)
    {
      for (item in inventory)
        if (item.id == id)
          {
            var name = (game.player.knowsItem(item.info.id) ?
              item.name : item.info.unknown);
            game.player.log('You take the ' + name + ' out of the gun cabinet.');
            game.player.host.inventory.add(item);
            inventory.remove(id);
            break;
          }
    }
}
