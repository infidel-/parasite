// item type

package game;

typedef Item = 
{
  id: String, // item id
  name: String, // actual item name (from a group of names)
  info: ItemInfo, // item info link
  ?event: scenario.Event, // scenario event link (for clues)
};
