// basic world region info

package game;

import const.WorldConst;
import region.*;
import _AreaType;

class RegionGame extends _SaveObject
{
  static var _ignoredFields = [ '_array', 'info' ];
  var game: Game;

  public var id: Int; // area id
  public var typeID: String; // region type id - city, military base, etc
  public var info: RegionInfo; // region info link
  public var width: Int;
  public var height: Int;

  var _array: Array<Array<AreaGame>>; // 2-dim array of areas for quicker access
  var _list: Map<Int, AreaGame>; // hashmap of areas (can include additional areas)
  var _objects: Map<Int, RegionObject>; // region objects list

  public static var _maxID: Int = 0; // region id counter

  public function new(g: Game, tv: String, w: Int, h: Int)
    {
      game = g;
      typeID = tv;
      id = _maxID++;
      width = w;
      height = h;
      init();
      initPost(false);
    }

// init object before loading/post creation
  public function init()
    {
      _list = new Map();
      _array = [];
      for (i in 0...width)
        _array[i] = [];
      _objects = new Map();
    }

// called after load or creation
  public function initPost(onLoad: Bool)
    {
      info = WorldConst.getRegionInfo(typeID);
      if (onLoad)
        {
          _array = [];
          for (i in 0...width)
            _array[i] = [];
          for (a in _list)
            {
              if (a.x >= 0 && a.y >= 0)
                _array[a.x][a.y] = a;
            }
        }
    }

// iterator
  public function iterator()
    { return _list.iterator(); }


// enter this region
  public function enter()
    {
      game.debug('Region.enter()');
      game.scene.sounds.setAmbient(AMBIENT_REGION);
      game.region = this;

      // no need to generate region here for now, it's generated in game/World
      // generate();

      // update region view info
      game.scene.region.update();

      // update music
      game.scene.sounds.onEnterRegion();

      // show region
      game.scene.region.show();

      // tutorial
      if (game.playerRegion.currentArea.alertness > 20)
        game.goals.complete(GOAL_TUTORIAL_AREA_ALERT);
    }


// leave the region: hide gui, etc
  public inline function leave()
    {
      game.debug('Region.leave()');

      // hide gui
      game.scene.region.hide();
    }


// turn in region mode
  public function turn()
    {
      // decrease area alertness everywhere
      for (y in 0...height)
        for (x in 0...width)
          {
            var a = game.region.getXY(x, y);
            if (a.alertness == 0)
              continue;

            a.alertness -= 1;
          }

      game.scene.region.update();
    }


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
            var t: _AreaType = AREA_GROUND;
            if (tmp[x][y] == 1)
              t = AREA_CITY_LOW;
            else if (tmp[x][y] == 2)
              t = AREA_CITY_MEDIUM;
            else if (tmp[x][y] == 3)
              t = AREA_CITY_HIGH;

            var a = new AreaGame(game, this, t, x, y);
            _list.set(a.id, a);
            _array[x][y] = a;
          }

      // add high crime city sections
      addHighCrime();

      // spawn 2 bases and 3 facilities (on the ground)
      spawnArea(AREA_MILITARY_BASE, true);
      spawnArea(AREA_MILITARY_BASE, true);
      spawnArea(AREA_FACILITY, true);
      spawnArea(AREA_FACILITY, true);
      spawnArea(AREA_FACILITY, true);
      // spawn 2 corp offices
      for (i in 0...2)
        {
          var a = getRandom({ type: AREA_CITY_HIGH, noEvents: true });
          var o = new region.CorpHQ(game, a.x, a.y);
          addObject(o);
          a.setType(AREA_CORP);
        }
    }

// adjust low-density city blocks to introduce high-crime pockets
  function addHighCrime()
    {
      // gather low-density city areas
      var lowAreas = [];
      for (area in _list)
        if (area.typeID == AREA_CITY_LOW)
          lowAreas.push(area);
      if (lowAreas.length == 0)
        return;

      // roll for primary high-crime seeds
      var added = 0;
      for (area in lowAreas)
        {
          if (Std.random(100) >= 20)
            continue;

          if (!area.highCrime)
            {
              area.highCrime = true;
              added++;
            }

          // spread high crime to adjacent similar blocks
          for (yy in (area.y - 1)...(area.y + 2))
            for (xx in (area.x - 1)...(area.x + 2))
              {
                if (xx == area.x && yy == area.y)
                  continue;

                var neighbor = getXY(xx, yy);
                if (neighbor == null ||
                    neighbor.typeID != area.typeID)
                  continue;

                if (Std.random(100) >= 60)
                  continue;

                if (!neighbor.highCrime)
                  {
                    neighbor.highCrime = true;
                    added++;
                  }
              }
        }

      // ensure at least a few high-crime hotspots exist
      if (added > 0)
        return;

      var fallbackCount =
         (lowAreas.length > 3 ? 3 : lowAreas.length);
      for (_ in 0...fallbackCount)
        {
          var idx = Std.random(lowAreas.length);
          var forced = lowAreas[idx];
          if (!forced.highCrime)
            forced.highCrime = true;
          lowAreas.splice(idx, 1);
        }
    }


// update areas alertness (called on entering region mode for this region)
  public function updateAlertness()
    {
      // make empty array
      var tmp = new Array<Array<Null<Float>>>();
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


// get habitats list in this area
  public function getHabitatsList(): Array<AreaGame>
    {
      var tmp = new Array();
      for (area in _list)
        if (area.isHabitat)
          tmp.push(area);

      return tmp;
    }


// get area by id
  public inline function get(id: Int): AreaGame
    {
      return _list.get(id);
    }


// get cells array
  public inline function getCells()
    { return _array; }


// get area by x,y
  public function getXY(x: Int, y: Int): AreaGame
    {
      if (x >= 0 && x < width && y >= 0 && y < height)
        return _array[x][y];

      return null;
    }

// get mission area based on target info
  public function getMissionArea(target: _MissionTarget): AreaGame
    {
      // first try - no events
      var area = getRandom({
        noMission: true,
        noEvents: true,
        noThrow: true,
        type: target.location,
      });
      if (area != null)
        return area;
      // second try - allow events (for lack of better options)
      area = getRandom({
        noMission: true,
        noThrow: true,
        type: target.location,
      });
      return area;
    }

// get random area
  public function getRandom(?params: {
    ?noMission: Bool,
    ?noEvents: Bool,
    ?noThrow: Bool,
    ?type: _AreaType
  }): AreaGame
    {
      var tmp: Array<AreaGame> = Lambda.array(_list);
      if (params == null)
        return tmp[Std.random(tmp.length)];
      var tmp2 = [];
      for (a in tmp)
        {
          // filter by mission area
          if (params.noMission &&
              a.isMissionArea())
            continue;

          // filter by events
          if (params.noEvents &&
              a.events.length > 0)
            continue;

          // filter by type
          if (params.type != null &&
              a.typeID != params.type)
            continue;

          tmp2.push(a);
        }

      if (tmp2.length == 0)
        {
          if (params.noThrow == true)
            return null;
          throw 'cannot find area with specified parameters: ' + params;
        }

      return tmp2[Std.random(tmp2.length)];
    }

// get random area around this one
  public function getRandomAround(area: AreaGame, params: {
    ?isInhabited: Bool,
    ?minRadius: Int,
    ?maxRadius: Int,
    ?type: _AreaType,
    ?canReturnNull: Bool
    } ): AreaGame
    {
      if (params.minRadius == null)
        params.minRadius = 1;
      if (params.maxRadius == null)
        params.maxRadius = 5;

      var tmp2 = [];
      var amin = null;
      var dist = 10000;
      for (a in _list)
        {
          // find only inhabited
          if (params.isInhabited != null &&
              a.info.isInhabited != params.isInhabited)
            continue;

          // find only with type
          if (params.type != null && a.info.id != params.type)
            continue;

          var tmpdist = Const.distanceSquared(a.x, a.y, area.x, area.y);
          if (a.x != area.x && a.x != area.y && tmpdist < dist)
            {
              amin = a;
              dist = tmpdist;
            }

          if (tmpdist >= params.minRadius * params.minRadius &&
              tmpdist <= params.maxRadius * params.maxRadius)
            tmp2.push(a);
        }

      // found some areas
      if (tmp2.length > 1)
        return tmp2[Std.random(tmp2.length)];

      // can return null and no areas found
      if (params.canReturnNull)
        return null;

      // no areas close, just use the closest one
      return amin;
    }

// spawn area with this type (actually just change some ground)
  public inline function spawnArea(t: _AreaType, noEvent: Bool): AreaGame
    {
      var a = getRandom({ type: AREA_GROUND, noEvents: noEvent });
      a.typeID = t;
      a.updateType();
      return a;
    }

// create a new area with this type (not on map, just somewhere in the region)
  public function createArea(t: _AreaType): AreaGame
    {
      var a = new AreaGame(game, this, t, -1, -1);
      _list.set(a.id, a);
      return a;
    }

// remove area in this region (only for non-cell areas)
  public function removeArea(areaID: Int)
    {
      _list.remove(areaID);
    }

// check if tile is walkable
  public function isWalkable(x: Int, y: Int): Bool
    {
      if (x < 0 || y < 0 || x >= width || y >= height)
        return false;

      return (Const.TILE_WALKABLE[_array[x][y].tileID] == 1);
    }

// get objects iterator
  public function getObjects(): Iterator<RegionObject>
    {
      return _objects.iterator();
    }

// add object to region (low-level)
  public inline function addObject(o: RegionObject)
    {
      _objects.set(o.id, o);
    }

// get object at (x,y)
// only one object per tile in region mode
  public function getObjectAt(x: Int, y: Int): RegionObject
    {
      for (o in _objects)
        if (o.x == x && o.y == y)
          return o;
      return null;
    }

// get object by type
// only one object per tile in region mode
  public function getObjectsWithType(type: String): Array<RegionObject>
    {
      var ret = [];
      for (o in _objects)
        if (o.type == type)
          ret.push(o);
      return ret;
    }
}
