// the safe in a military base's HQ armory (gen.military.MilitaryRooms): the gun cabinet's loot flow
// with the base's money, a laptop and its papers in it

package objects;

import const.ItemsConst;

class Safe extends GunCabinet
{
  // what a safe can hold besides its papers, weighted
  public static var SAFE_LOOT: Array<{ id: String, weight: Int }> = [
    { id: 'money', weight: 20 },
    { id: 'paper', weight: 50 },
    { id: 'laptop', weight: 30 },
  ];
  // and how many clue documents it holds on top of that roll
  static inline var CLUES_MIN = 2;
  static inline var CLUES_MAX = 3;
  // how many of them are reports, the rest books: AreaGame.spawnDocument's split
  static inline var CLUE_PAPER_PCT = 80;

// init object before loading/post creation
  public override function init()
    {
      super.init();
      type = 'safe';
      name = 'safe';
    }

// one roll off its table, and its papers. A paper is a clue about a timeline event, so it is made
// with one (Readable reads its event): Inventory.addID makes items with none
  override function fill()
    {
      var id = GunCabinet.rollLoot(loot());
      var n = CLUES_MIN + Std.random(CLUES_MAX - CLUES_MIN + 1);
      if (id == 'paper')
        n++;
      else inventory.addID(id);
      for (_ in 0...n)
        {
          var e = clueEvent();
          if (e == null)
            return;
          var info = ItemsConst.getInfo(Std.random(100) < CLUE_PAPER_PCT ? 'paper' : 'book');
          inventory.add({
            game: game,
            id: info.id,
            name: info.names[Std.random(info.names.length)],
            info: info,
            event: e,
          });
        }
    }

// the event a paper in it is about: one of the base's own, else any the timeline does not hide, or
// null for a timeline with none
  function clueEvent(): scenario.Event
    {
      var area = game.region.get(areaID);
      if (area.events.length > 0)
        return area.events[Std.random(area.events.length)];
      var list = [for (e in game.timeline) if (!e.isHidden) e];
      return (list.length > 0 ? list[Std.random(list.length)] : null);
    }

// a safe's contents
  override function loot(): Array<{ id: String, weight: Int }>
    { return SAFE_LOOT; }

// the 3D prop, open or shut
  public override function getModelKey(): String
    { return (isOpen ? 'safeOpen' : 'safe'); }
}
