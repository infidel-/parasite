// item type

package game;

typedef _Item =
{
  id: String, // item id
  name: String, // actual item name (from a group of names)
  info: _ItemInfo, // item info link
  ?event: scenario.Event, // scenario event link (for clues)
};
