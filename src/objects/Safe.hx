// the safe in a military base's HQ armory (gen.military.MilitaryRooms): the gun cabinet's loot flow
// with the base's money and papers in it

package objects;

class Safe extends GunCabinet
{
  // what a safe can hold, weighted
  public static var SAFE_LOOT: Array<{ id: String, weight: Int }> = [
    { id: 'money', weight: 50 },
    { id: 'paper', weight: 30 },
    { id: 'laptop', weight: 20 },
  ];

// init object before loading/post creation
  public override function init()
    {
      super.init();
      type = 'safe';
      name = 'safe';
    }

// a safe's contents
  override function loot(): Array<{ id: String, weight: Int }>
    { return SAFE_LOOT; }

// the 3D prop, open or shut
  public override function getModelKey(): String
    { return (isOpen ? 'safeOpen' : 'safe'); }
}
