// basic world region info

package game;

import const.WorldConst;

class RegionGame
{
  var game: Game;

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

  public function new(g: Game, tv: String, w: Int, h: Int)
    {
      game = g;
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


// enter this region
  public function enter()
    {
      game.debug('Region.enter()');

      game.region = this;

      // no need to generate region here for now, it's generated in game/World
      // generate();

      // update region view info
      game.scene.region.update();

      // update cell visibility to player
      updateVisibility();

      // show region
      game.scene.region.show();
    }


// leave thie region: hide gui, etc
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

      // try to detect all habitats
      turnDetectHabitats();

      // update all icons
      game.scene.region.updateIcons();
    }


// TURN: try to detect all habitats
// also called when player is in the area mode once/10 turns
  public function turnDetectHabitats()
    {
      var params = game.player.evolutionManager.getParams(IMP_MICROHABITAT);
      var detectionChance: Float = params.detectionChance;
      var tmp = getHabitatsList();
      for (area in tmp)
        {
          // skip current area if it's a habitat and player is it
          if (game.location == LOCATION_AREA && area == game.area)
            continue;

          var ret = _Math.detectHabitat({
            base: detectionChance,
            interest: area.parent.interest
          });
          if (!ret)
            continue;

          game.debug("Habitat " + id + " detected.");
          area.habitatIsDetected = true;
        }
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

      // spawn 2 bases and 3 facilities
      spawnArea(AREA_MILITARY_BASE, true);
      spawnArea(AREA_MILITARY_BASE, true);
      spawnArea(AREA_FACILITY, true);
      spawnArea(AREA_FACILITY, true);
      spawnArea(AREA_FACILITY, true);
    }


// update cell visibility
  public inline function updateVisibility()
    {
      game.scene.region.updateVisibility();
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
  public function getHabitatsList(): List<AreaGame>
    {
      var tmp = new List();
      for (area in _list)
        if (area.isHabitat)
          tmp.add(area);

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
  public function getRandomWithType(t: _AreaType, noEvent: Bool): AreaGame
    {
      var tmp: Array<AreaGame> = Lambda.array(_list);
      var tmp2 = [];
      for (a in tmp)
        if (a.typeID == t && (!noEvent || a.events.length == 0))
          tmp2.push(a);

      if (tmp2.length == 0)
        return null;

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

          var tmpdist = Const.getDistSquared(a.x, a.y, area.x, area.y);
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
      var a = getRandomWithType(AREA_GROUND, noEvent);
      a.setType(t);
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

      return Const.TILE_WALKABLE_REGION[_array[x][y].tileID];
    }


// ========================== SETTERS ====================================
/*
  function set_alertness(v: Float)
    { return alertness = Const.clampFloat(v, 0, 100.0); }
  function set_interest(v: Float)
    { return interest = Const.clampFloat(v, 0, 100.0); }
*/
}
