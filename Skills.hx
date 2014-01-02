// player/AI inventory

import ConstItems;

class Inventory
{
  var _list: List<Item>; // list of items

  public function new()
    {
      _list = new List<Item>();
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
}


// item type

typedef Item = 
{
  var id: String; // item id
  var info: ItemInfo; // item info link
};
