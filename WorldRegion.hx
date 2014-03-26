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
      if (typeID == ConstWorld.REGION_CITY)
        generateCity();

      else throw 'unsupported region type: ' + typeID;
    }


// helper: trace tmp array
  function traceTmp(tmp: Array<Array<Int>>)
    {
      // debug output
      for (y in 0...height)
        {
          var s = '';
          for (x in 0...width)
            {
              s += tmp[x][y];
            }
          trace(s);
        }
    }


// helper: smooth cells adjacent to this one
  inline function smoothAdjacentTmp(tmp: Array<Array<Int>>, x: Int, y: Int)
    {
      if (y - 1 >= 0 && tmp[x][y - 1] == 0)
        tmp[x][y - 1] = 1;
      if (y + 1 < height && tmp[x][y + 1] == 0)
        tmp[x][y + 1] = 1;

      if (x - 1 >= 0 && tmp[x - 1][y] == 0)
        tmp[x - 1][y] = 1;
      if (x + 1 < width && tmp[x + 1][y] == 0)
        tmp[x + 1][y] = 1;
    }


// generate: city
  function generateCity()
    {
      // make empty array
      var tmp = new Array<Array<Int>>();
      for (i in 0...width)
        tmp[i] = [];

      // fill array with zeroes
      for (y in 0...height)
        for (x in 0...width)
          tmp[x][y] = 0;

      // form a few peaks near the center of map
      var numPeaks = Std.int(width * height / 25);
      for (i in 0...numPeaks)
        {
          var x = Std.int(width / 4 + Std.random(Std.int(width / 2)));
          var y = Std.int(height / 4 + Std.random(Std.int(height/ 2)));
          tmp[x][y] = 7 + Std.random(3);
        }

//      trace(0);
//      traceTmp(tmp);

      // smooth peaks a few times
//      var numSmooth = Std.int(width * height / 100);
      for (i in 0...4)//numSmooth)
        for (y in 0...height)
          for (x in 0...width)
            if (tmp[x][y] > 1)
              {
                if (y - 1 >= 0 && tmp[x][y - 1] == 0)
                  tmp[x][y - 1] = tmp[x][y] - 1;
                if (y + 1 < height && tmp[x][y + 1] == 0)
                  tmp[x][y + 1] = tmp[x][y] - 1;

                if (x - 1 >= 0 && tmp[x - 1][y] == 0)
                  tmp[x - 1][y] = tmp[x][y] - 1;
                if (x + 1 < width && tmp[x + 1][y] == 0)
                  tmp[x + 1][y] = tmp[x][y] - 1;
              }

//      trace('s');
//      traceTmp(tmp);

      // normalize results
      for (y in 0...height)
        for (x in 0...width)
          tmp[x][y] = Std.int(tmp[x][y] * 3.0 / 9.0);

//      trace('n');
//      traceTmp(tmp);

      // roughen up edges
      var chance = 30;
      for (y in 0...height)
        for (x in 0...width)
          if (tmp[x][y] == 0)
            {
              if (y - 1 >= 0 && tmp[x][y - 1] == 1 && Std.random(100) < chance)
                tmp[x][y - 1] = 0;
              if (y + 1 < height && tmp[x][y + 1] == 1 && Std.random(100) < chance)
                tmp[x][y + 1] = 0;

              if (x - 1 >= 0 && tmp[x - 1][y] == 1 && Std.random(100) < chance)
                tmp[x - 1][y] = 0;
              if (x + 1 < width && tmp[x + 1][y] == 1 && Std.random(100) < chance)
                tmp[x + 1][y] = 0;
            }
      
//      trace('r');
//      traceTmp(tmp);

      // smooth over again
      for (y in 0...height)
        for (x in 0...width)
          if (tmp[x][y] == 3)
            smoothAdjacentTmp(tmp, x, y);

//      trace('s2');
//      traceTmp(tmp);

      // and again (seriously, for the last time!
      for (y in 0...height)
        for (x in 0...width)
          if (tmp[x][y] == 2)
            smoothAdjacentTmp(tmp, x, y);

//      trace('s3');
//      traceTmp(tmp);

      for (y in 0...height)
        for (x in 0...width)
          {
            var t = ConstWorld.AREA_GROUND;
            if (tmp[x][y] == 1)
              t = ConstWorld.AREA_CITY_LOW;
            else if (tmp[x][y] == 2)
              t = ConstWorld.AREA_CITY_MEDIUM;
            else if (tmp[x][y] == 3)
              t = ConstWorld.AREA_CITY_HIGH;

            var a = new RegionArea(t, x, y, 50, 50);
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
