// basic world region info

import ConstWorld;

class WorldRegion
{
  public var id: Int; // area id
  public var typeID: String; // region type id - city, military base, etc
  public var info: RegionInfo; // region info link
  public var width: Int;
  public var height: Int;
//  public var alertness(default, set): Float; // area alertness (authorities) (0-100%)
//  public var interest(default, set): Float; // area interest for secret groups (0-100%)

  var _list: Map<Int, RegionArea>; // hashmap of areas

  static var _maxID: Int = 0; // region id counter

  public function new(tv: String, w: Int, h: Int)
    {
      typeID = tv;
      id = _maxID++;
      width = w;
      height = h;
      info = ConstWorld.getRegionInfo(typeID);
//      alertness = 0;
//      interest = 0;
      _list = new Map<Int, RegionArea>();
    }


// generate a region
  public function generate()
    {
      for (y in 0...height)
        for (x in 0...width)
          {
            var a = new RegionArea(ConstWorld.AREA_CITY_BLOCK, x, y, 50, 50);
            _list.set(a.id, a);
          }
    }


// get area by id
  public inline function get(id: Int): RegionArea
    {
      return _list.get(id);
    }


// get area by x,y
  public function getXY(x: Int, y: Int): RegionArea
    {
      for (r in _list)
        if (r.x == x && r.y == y)
          return r;

      return null;
    }


// get random area
  public function getRandom(): RegionArea
    {
      var tmp: Array<RegionArea> = Lambda.array(_list);
      return tmp[Std.random(tmp.length)];
    }


// ========================== SETTERS ====================================
/*
  function set_alertness(v: Float)
    { return alertness = Const.clampFloat(v, 0, 100.0); }
  function set_interest(v: Float)
    { return interest = Const.clampFloat(v, 0, 100.0); }
*/    
}
