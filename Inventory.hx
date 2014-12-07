// player/AI inventory

import ConstItems;

class Inventory
{
  var game: Game;
  var _list: List<Item>; // list of items

  public function new(g: Game)
    {
      game = g;
      _list = new List<Item>();
    }


// add available actions to list
  public function getActions(): List<_PlayerAction>
    {
      var tmp = new List<_PlayerAction>();
      for (item in _list)
        {
          // add learning action
          if (!game.player.knowsItem(item.id))
            tmp.add({
              id: 'learn.' + item.id,
              type: ACTION_INVENTORY,
              name: 'Learn about ' + item.info.unknown,
              energy: 10,
              obj: item
              });

          // cant do stuff when item is not known
          if (!game.player.knowsItem(item.id))
            continue;

          if (item.info.type == 'readable')
            tmp.add({ 
              id: 'read.' + item.id,
              type: ACTION_INVENTORY,
              name: 'Read ' + item.name,
              energy: 10,
              obj: item
              });
        }

      return tmp;
    }


// ACTION: player inventory action
  public function action(action: _PlayerAction)
    {
      var item: Item = untyped action.obj;
      var actionID = action.id.substr(0, action.id.indexOf('.'));
  
      // learn about item
      if (actionID == 'learn')
        actionLearn(item);
    
      // read item
      else if (actionID == 'read')
        actionRead(item);
    
      // spend energy
      game.player.host.energy -= action.energy;

      if (game.location == Game.LOCATION_AREA)
        game.area.player.postAction();

      else Const.todo('Inventory.action() in region mode!');
    }


// ACTION: read item
  function actionRead(item: Item)
    {
      game.log('You study the contents of the ' + item.name + '.');
      game.timeline.getClue(item.event);
    }


// ACTION: learn about item
  function actionLearn(item: Item)
    {
      game.log('You probe the brain of the host and learn what that item is for.');

      game.player.addKnownItem(item.id);
    }


// list iterator
  public function iterator(): Iterator<Item>
    {
      return _list.iterator();
    }


// clear list
  public inline function clear()
    {
      _list.clear();
    }


// remove item
  public function remove(id: String)
    {
      for (item in _list)
        if (item.id == id)
          {
            _list.remove(item);
            break;
          }
    }


// get first item that is a weapon
  public function getFirstWeapon(): Item
    {
      for (item in _list)
        if (item.info.weaponStats != null)
          return item;

      return null;
    }


// add item by id
  public function addID(id: String)
    {
      var info = ConstItems.getInfo(id);
      if (info == null)
        {
          trace('No such item id: ' + id);
          return;
        }

      var name = info.name;
      if (info.names != null) // pick a name
        name = info.names[Std.random(info.names.length)];
      var item = { id: id, info: info, name: name };
      _list.add(item);
    }


// add item
  public inline function add(item: Item)
    {
      _list.add(item);
    }


  public function toString(): String
    {
      var tmp = [];
      for (o in _list)
        tmp.push(o.id);
      return tmp.join(', ');
    }


// ===============================================================================
}

