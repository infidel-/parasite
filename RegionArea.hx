// basic region area info

import ConstWorld;

class RegionArea
{
  public var id: Int; // area id
  public var typeID: String; // area type id - city block, university, military base, etc
  public var tileID: Int; // tile id on tilemap
  public var info: AreaInfo; // area info link
  public var width: Int;
  public var height: Int;
  public var x: Int; // x,y in region
  public var y: Int;

  public var alertness(default, set): Float; // area alertness (authorities) (0-100%)
  public var interest(default, set): Float; // area interest for secret groups (0-100%)

  static var _maxID: Int = 0; // area id counter

  public function new(tv: String, vx: Int, vy: Int, w: Int, h: Int)
    {
      typeID = tv;
      id = _maxID++;
      x = vx;
      y = vy;
      width = w;
      height = w;
      info = ConstWorld.getAreaInfo(typeID);
      alertness = 0;
      interest = 0;

      if (typeID == ConstWorld.AREA_GROUND)
        tileID = Const.TILE_REGION_GROUND;
      else if (typeID == ConstWorld.AREA_CITY_LOW)
        tileID = Const.TILE_REGION_CITY_LOW;
      else if (typeID == ConstWorld.AREA_CITY_MEDIUM)
        tileID = Const.TILE_REGION_CITY_MEDIUM;
      else if (typeID == ConstWorld.AREA_CITY_HIGH)
        tileID = Const.TILE_REGION_CITY_HIGH;
    }


// ========================== SETTERS ====================================

  function set_alertness(v: Float)
    { return alertness = Const.clampFloat(v, 0, 100.0); }
  function set_interest(v: Float)
    { return interest = Const.clampFloat(v, 0, 100.0); }
}
