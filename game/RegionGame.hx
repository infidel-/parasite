// basic world region info

package game;

import const.WorldConst;

class RegionGame
{
  public var id: Int; // area id
  public var typeID: String; // region type id - city, military base, etc
  public var info: RegionInfo; // region info link
  public var width: Int;
  public var height: Int;
//  public var alertness(default, set): Float; // area alertness (authorities) (0-100%)
//  public var interest(default, set): Float; // area interest for secret groups (0-100%)

  var _array: Array<Array<AreaGame>>; // 2-dim array of areas for quicker access
  var _list: Map<Int, AreaGame>; // hashmap of areas (can include additional areas)

  static var _maxID: Int = 0; // region id counter

  public function new(tv: String, w: Int, h: Int)
    {
      typeID = tv;
      id = _maxID++;
      width = w;
      height = h;
      info = WorldConst.getRegionInfo(typeID);
//      alertness = 0;
//      interest = 0;
      _list = new Map<Int, AreaGame>();

      _array = new Array<Array<AreaGame>>();
      for (i in 0...width)
        _array[i] = [];
    }


// iterator
  public function iterator()
    { return _list.iterator(); }


// generate a region
  public function generate()
    {
      if (typeID == WorldConst.REGION_CITY)
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
            var t = WorldConst.AREA_GROUND;
            if (tmp[x][y] == 1)
              t = WorldConst.AREA_CITY_LOW;
            else if (tmp[x][y] == 2)
              t = WorldConst.AREA_CITY_MEDIUM;
            else if (tmp[x][y] == 3)
              t = WorldConst.AREA_CITY_HIGH;

            var a = new AreaGame(this, t, x, y, 50, 50);
            _list.set(a.id, a);
            _array[x][y] = a;
          }
    }


// update areas alertness (called on entering region mode for this region)
  public function updateAlertness()
    {
      // make empty array
      var tmp = new Array<Array<Float>>();
      for (i in 0...width)
        tmp[i] = [];

      // loop through all areas propagating alertness changes to adjacent areas
      for (y in 0...height)
        for (x in 0...width)
          {
            var a = _array[x][y];

            for (yy in (y - 1)...(y + 2))
              for (xx in (x - 1)...(x + 2))
                {
                  var aa = getXY(xx, yy);
                  if (aa == null || aa == a || !aa.info.canEnter)
                    continue;

                  if (tmp[xx][yy] == null)
                    tmp[xx][yy] = 0;
                  tmp[xx][yy] += 0.75 * a.alertnessMod;
                }

            // reset alertness changes 
            a.alertnessMod = 0;
          }

      // store alertness changes 
      for (y in 0...height)
        for (x in 0...width)
          if (tmp[x][y] != null)
            _array[x][y].setAlertness(_array[x][y].alertness + tmp[x][y]); 
    }


// get habitats count in this area
  public function getHabitatsCount(): Int
    {
      var cnt = 0;
      for (area in _list)
        if (area.isHabitat)
          cnt++;
      
      return cnt;
    }


// get area by id
  public inline function get(id: Int): AreaGame
    {
      return _list.get(id);
    }


// get area by x,y
  public function getXY(x: Int, y: Int): AreaGame
    {
      if (x >= 0 && x < width && y >= 0 && y < height)
        return _array[x][y];
/*    
      for (r in _list)
        if (r.x == x && r.y == y)
          return r;
*/
      return null;
    }


// get random area
  public function getRandom(): AreaGame
    {
      var tmp: Array<AreaGame> = Lambda.array(_list);
      return tmp[Std.random(tmp.length)];
    }


// get random inhabited area
  public function getRandomInhabited(): AreaGame
    {
      var tmp: Array<AreaGame> = Lambda.array(_list);
      var tmp2 = [];
      for (a in tmp)
        if (a.info.isInhabited)
          tmp2.push(a);

      if (tmp2.length == 0)
        throw 'cannot find enterable area';

      return tmp2[Std.random(tmp2.length)];
    }


// get random enterable area
  public function getRandomEnterable(): AreaGame
    {
      var tmp: Array<AreaGame> = Lambda.array(_list);
      var tmp2 = [];
      for (a in tmp)
        if (a.info.canEnter)
          tmp2.push(a);

      if (tmp2.length == 0)
        throw 'cannot find enterable area';

      return tmp2[Std.random(tmp2.length)];
    }


// get random area with this type id
  public function getRandomWithType(t: String, noEvent: Bool): AreaGame
    {
      var tmp: Array<AreaGame> = Lambda.array(_list);
      var tmp2 = [];
      for (a in tmp)
        if (a.typeID == t && (!noEvent || a.event == null))
          tmp2.push(a);

      if (tmp2.length == 0)
        return null;

      return tmp2[Std.random(tmp2.length)];
    }


// get random area around this one
  public function getRandomAround(area: AreaGame, ?isInhabited: Bool): AreaGame
    {
      var tmp: Array<AreaGame> = [];

      var a = getXY(area.x, area.y);
      if (a != null && (isInhabited == null || a.info.isInhabited == isInhabited))
        tmp.push(a);

      for (i in 0...Const.dirx.length)
        {
          var a = getXY(area.x + Const.dirx[i], area.y + Const.diry[i]);
          if (a != null && (isInhabited == null || a.info.isInhabited == isInhabited))
            tmp.push(a);
        }

      // at least one area found
      if (tmp.length > 0)
        return tmp[Std.random(tmp.length)];

      // no inhabitable areas found, find inhabitable area in radius 5
      // and closest one
      var tmp2 = [];
      var amin = null;
      var dist = 10000;
      for (a in _list)
        {
          if (isInhabited != null && a.info.isInhabited != isInhabited)
            continue;

          var tmpdist = Const.getDistSquared(a.x, a.y, area.x, area.y);
          if (a.x != area.x && a.x != area.y && tmpdist < dist)
            {
              amin = a;
              dist = tmpdist; 
            }

          if (tmpdist < 25)
            tmp2.push(a);
        }

      // found some areas in radius 5
      if (tmp2.length > 1)
        return tmp2[Std.random(tmp2.length)];

      // no areas close, just use the closest one
      return amin;
    }


// spawn area with this type (actually just change some ground)
  public inline function spawnArea(t: String, noEvent: Bool): AreaGame
    {
      var a = getRandomWithType(WorldConst.AREA_GROUND, noEvent);
      a.setType(t);
      return a;
    }


// create a new area with this type (not on map, just somewhere in the region)
  public function createArea(t: String): AreaGame
    {
      var a = new AreaGame(this, t, -1, -1, 50, 50);
      _list.set(a.id, a);
      return a;
    }


// ========================== SETTERS ====================================
/*
  function set_alertness(v: Float)
    { return alertness = Const.clampFloat(v, 0, 100.0); }
  function set_interest(v: Float)
    { return interest = Const.clampFloat(v, 0, 100.0); }
*/    
}
