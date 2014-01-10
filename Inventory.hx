// player/AI inventory

import ConstItems;

class Inventory
{
  var _list: List<Item>; // list of items

  public function new()
    {
      _list = new List<Item>();
    }


  public function iterator(): Iterator<Item>
    {
      return _list.iterator();
    }


// clear list
  public inline function clear()
    {
      _list.clear();
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

      var item = { id: id, info: info };
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


// item type

typedef Item = 
{
  var id: String; // item id
  var info: ItemInfo; // item info link
};
