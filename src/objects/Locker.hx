// a steel locker in a military base's armory (gen.military.MilitaryRooms): the gun cabinet's loot
// flow with a soldier's kit in it instead of a weapon rack's

package objects;

class Locker extends GunCabinet
{
  // what a locker can hold, weighted
  public static var LOCKER_LOOT: Array<{ id: String, weight: Int }> = [
    { id: 'kevlarArmor', weight: 25 },
    { id: 'knife', weight: 20 },
    { id: 'cigarettes', weight: 20 },
    { id: 'radio', weight: 15 },
    { id: 'pistol', weight: 10 },
    { id: 'alcohol', weight: 10 },
  ];

// init object before loading/post creation
  public override function init()
    {
      super.init();
      type = 'locker';
      name = 'locker';
    }

// a locker's kit
  override function loot(): Array<{ id: String, weight: Int }>
    { return LOCKER_LOOT; }

// the 3D prop, open or shut
  public override function getModelKey(): String
    { return (isOpen ? 'lockerOpen' : 'locker'); }
}
