// player/AI inventory

package game;

import const.ItemsConst;

class Inventory extends _SaveObject
{
  var game: Game;
  var _list: List<_Item>; // list of items
  public var weaponID: String; // currently active weapon

  // item slots
  public var clothing(default, null): _Item;

  public function new(g: Game)
    {
      game = g;
      init();
      initPost(false);
    }

// init object before loading/post creation
  public function init()
    {
      _list = new List();
      var info = ItemsConst.getInfo('armorNone');
      clothing = {
        game: game,
        id: info.id,
        info: info,
        name: info.name,
        event: null,
      };
      weaponID = null;
    }

// called after load or creation
  public function initPost(onLoad: Bool)
    {
    }

// add available actions to list (body window)
  public function getActions(): Array<_PlayerAction>
    {
      // disable inventory actions in region mode for now
      var tmp = [];
      if (game.location == LOCATION_REGION)
        return tmp;

      for (item in _list)
        {
          var itemName = item.getName();
          // add learning action
          if (!game.player.knowsItem(item.id))
            tmp.push({
              id: 'learn.' + item.id,
              type: ACTION_INVENTORY,
              name: 'Learn about ' + Const.col('inventory-item', itemName),
              energy: 10,
              isAgreeable: true,
              item: item
            });

          // can do stuff when item is known
          else
            {
              var itemActions = item.info.getInventoryActions(item);
              for (action in itemActions)
                tmp.push(action);
            }

          // drop item
          tmp.push({
            id: 'drop.' + item.id,
            type: ACTION_INVENTORY,
            name: 'Drop ' + Const.col('inventory-item', itemName),
            energy: 0,
            item: item
          });
        }
      return tmp;
    }

// update actions list (hud)
  public function updateActionList()
    {
      for (item in _list)
        item.info.updateActionList(item);
    }

// ACTION: player inventory action
  public function action(action: _PlayerAction)
    {
      var actionID = action.id.substr(0, action.id.indexOf('.'));
      var ret = true;
      switch (actionID)
        {
          // drop item
          case 'drop':
            dropAction(action.item);
          // learn about item
          case 'learn':
            learnAction(action.item);
          default:
            {
              var handled: Null<Bool> = (action.item != null ?
                action.item.info.action(actionID, action.item) : null);
              if (handled == null)
                Const.todo('no such action: ' + actionID);
              else ret = handled;
            }
        }

      // if action was completed, end turn, etc
      if (ret)
        {
          // spend energy
          game.player.actionEnergy(action);
          // end turn, etc
          if (game.location == LOCATION_AREA)
            game.playerArea.actionPost();

          else Const.todo('Inventory.action() in region mode!');
        }
    }

// ACTION: learn about item
  function learnAction(item: _Item)
    {
      game.log('You probe the brain of the host and learn that this item is a ' +
        Const.col('inventory-item', item.name) + '.');
      game.player.addKnownItem(item.id);
      item.info.onLearn();

      // on first learn items
      game.goals.complete(GOAL_LEARN_ITEMS);

      // goal completion
      if (item.info.type == 'phone' ||
          item.id == 'smartphone' ||
          item.info.type == 'radio')
        game.goals.complete(GOAL_TUTORIAL_COMMS);
    }


// ACTION: drop item
  function dropAction(item: _Item)
    {
      game.area.addItem(game.playerArea.x, game.playerArea.y, item);
      _list.remove(item);
      var itemName = (game.player.knowsItem(item.info.id) ?
        item.name : item.info.unknown);
      game.player.log('You drop the ' + Const.col('inventory-item', itemName) + '.');
      game.scene.sounds.play('item-drop');
    }

// list iterator
  public function iterator(): Iterator<_Item>
    {
      return _list.iterator();
    }


// clear list
  public inline function clear()
    {
      _list.clear();
    }

// checks whether this inventory contains this item ID
  public function has(id: String): Bool
    {
      for (item in _list)
        if (item.id == id)
          return true;
      return false;
    }

// returns first item with this id from this inventory
  public function get(id: String): _Item
    {
      for (item in _list)
        if (item.id == id)
          return item;
      return null;
    }

// returns all items with this id
  public function getAll(id: String): Array<_Item>
    {
      var ret = [];
      for (item in _list)
        if (item.id == id)
          ret.push(item);
      return ret;
    }

// remove item by id
  public function remove(id: String)
    {
      for (item in _list)
        if (item.id == id)
          {
            _list.remove(item);
            break;
          }
    }

// remove item
  public function removeItem(item: _Item)
    {
      _list.remove(item);
    }

// get first item that is a weapon
  public function getFirstWeapon(): _Item
    {
      for (item in _list)
        if (item.info.weapon != null)
          return item;

      return null;
    }


// add item by id
  public function addID(id: String, ?wear: Bool = false): _Item
    {
      var item = ItemsConst.spawnItem(game, id);
      // wear/wield item automatically
      if (wear)
        {
          if (item.info.type == 'clothing')
            clothing = item;
        }
      else _list.add(item);
      return item;
    }


// add item
  public inline function add(item: _Item)
    {
      _list.add(item);
    }

  public function length(): Int
    {
      return _list.length;
    }

  public function toString(): String
    {
      var tmp = [];
      for (o in _list)
        tmp.push(o.id);
      if (clothing.id != 'armorNone')
        tmp.push('clothing: ' + clothing.id);
      return tmp.join(', ');
    }
}
