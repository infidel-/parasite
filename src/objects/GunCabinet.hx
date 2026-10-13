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
  // and a military base armory's: the soldier's rifle (ai.SoldierAI), the officer's pistol
  // (ai.OfficerAI), the shotgun and a kevlar vest, none of the security guard's stun kit
  public static var MIL_LOOT: Array<{ id: String, weight: Int }> = [
    { id: 'assaultRifle', weight: 45 },
    { id: 'pistol', weight: 30 },
    { id: 'combatShotgun', weight: 25 },
    { id: 'kevlarArmor', weight: 20 },
  ];

  public var inventory: Inventory; // what it holds
  public var isOpen: Bool; // is its door open?
  public var isSearched: Bool; // has a host gone through it?

  public function new(g: Game, vaid: Int, vx: Int, vy: Int)
    {
      super(g, vaid, vx, vy);
      init();
      fill();
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

// put in what it holds: one item off its loot table. objects.Safe adds its papers
  function fill()
    {
      inventory.addID(rollLoot(loot()));
    }

// what this container can hold, weighted: a corp tower's or a military base's. objects.Locker and
// objects.Safe hand back their own
  function loot(): Array<{ id: String, weight: Int }>
    {
      return (game.region.get(areaID).typeID == AREA_MILITARY_BASE ?
        MIL_LOOT : LOOT);
    }

// one item id off a weighted loot table
  static function rollLoot(table: Array<{ id: String, weight: Int }>): String
    {
      var total = 0;
      for (l in table)
        total += l.weight;
      var roll = Std.random(total);
      for (l in table)
        {
          roll -= l.weight;
          if (roll < 0)
            return l.id;
        }
      return table[0].id;
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

// update actions: open, then search, then its Get, or one action opening the pickup submenu on what
// it holds when that is several. THE GETS ARE HERE AND NOT IN getItemActions, or a row of lockers
// pooled into the tile's one submenu with whatever lies on the floor
  override function updateActionList()
    {
      if (game.player.state != PLR_STATE_HOST)
        return;
      if (!isOpen)
        {
          game.ui.hud.addAction({
            id: 'openCabinet',
            type: ACTION_OBJECT,
            name: 'Open ' + name,
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
            name: 'Search ' + name,
            energy: 10,
            obj: this
          });
          return;
        }
      var gets = takeActions();
      if (gets.length == 1)
        game.ui.hud.addAction(gets[0]);
      else if (gets.length > 1)
        game.ui.hud.addAction({
          id: 'takeMenu',
          type: ACTION_OBJECT,
          name: 'Take from ' + name + '… ' + Const.col('inventory-item', '(' + gets.length + ')'),
          isVirtual: true,
          obj: this
        });
    }

// one Get per item it holds, none while the host's hands are full: its action, or the pickup
// submenu's list (ui.hud.ActionsHud)
  public function takeActions(): Array<_PlayerAction>
    {
      var list: Array<_PlayerAction> = [];
      if (game.player.host.inventory.length() >=
          game.player.host.maxItems)
        return list;
      for (item in inventory)
        {
          var name = (game.player.knowsItem(item.id) ?
            item.name : item.info.unknown);
          list.push({
            id: 'get.' + item.id,
            type: ACTION_OBJECT,
            name: 'Get ' + Const.col('inventory-item', name),
            energy: 5,
            obj: this
          });
        }
      return list;
    }

// ACTION: action handling
  override function onAction(action: _PlayerAction): Bool
    {
      if (action.id == 'openCabinet')
        openAction();
      else if (action.id == 'searchCabinet')
        searchAction();
      else if (action.id == 'takeMenu')
        {
          game.ui.hud.pickupFrom = this;
          game.ui.hud.state = HUD_PICKUP_MENU;
        }
      else if (action.id.substr(0, 4) == 'get.')
        getAction(action.id.substr(4));
      return true;
    }

// ACTION: open the door, and swap the 3D prop for the open one
  function openAction()
    {
      isOpen = true;
      game.log('You open the ' + name + '.');
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
          game.log('The ' + name + ' is empty.');
          return;
        }
      for (item in inventory)
        {
          var name = (game.player.knowsItem(item.id) ?
            item.name : item.info.unknown);
          game.log('You find ' + Const.col('inventory-item', name) + ' in the ' + this.name + '.');
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
            game.player.log('You take the ' + name + ' out of the ' + this.name + '.');
            game.player.host.inventory.add(item);
            inventory.remove(id);
            break;
          }
    }
}
