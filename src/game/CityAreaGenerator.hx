// city area generation

package game;

import const.WorldConst;
import Const;
import objects.*;
import game.AreaGame;
import game.AreaGenerator;
import game.AreaGenerator._GeneratorState;
import tiles.Default;

class CityAreaGenerator
{
  var game: Game;
  var gen: AreaGenerator;

// store references to the owning game and shared generator helpers
  public function new(g: Game, gn: AreaGenerator)
    {
      game = g;
      gen = gn;
    }

// generate a city block
  public function generate(state: _GeneratorState, area: AreaGame, info: AreaInfo)
    {
      var cells = area.getCells();
      // fill with proto-buildings
      for (y in 0...area.height)
        for (x in 0...area.width)
          cells[x][y] = TEMP_BUILDING;

      var blockW = Std.int(area.width / state.blockSize);
      var blockH = Std.int(area.height / state.blockSize);
      var blockW4 = Std.int(area.width / state.blockSize / 4);
      var blockH4 = Std.int(area.height / state.blockSize / 4);
      var bx = blockW4 + Std.random(blockW - 1 - blockW4);
      var by = blockH4 + Std.random(blockH - 1 - blockH4);

      // add all streets with spawn points for alleys
      // horizontal roads
      var noMainRoad = true;
      if (info.hasMainRoad == null || info.hasMainRoad == false)
        noMainRoad = false;
      var mainRoadChance = 20;
      for (i in 0...4)
        {
          var level = (noMainRoad &&
            Std.random(100) < mainRoadChance &&
            i > 0 && i < 3 ? 0 : 1);
          addStreet(state, area, cells, LR, 0,
            state.blockSize * (i + 1), level);
          if (level == 0)
            noMainRoad = false;
          else mainRoadChance += 20;
        }
      // vertical roads
      for (i in 0...4)
        {
          var level = (noMainRoad &&
            Std.random(100) < mainRoadChance &&
            i > 0 && i < 3 ? 0 : 1);
          addStreet(state, area, cells, TB,
            state.blockSize * (i + 1), 0, level);
          if (level == 0)
            noMainRoad = false;
          else mainRoadChance += 20;
        }

      // add alleys from points
      for (pt in state.alleys)
        if (Std.random(100) < 40)
          addAlley(area, pt, 2);

      // mark blocks
      var blocks = new List();
      for (y in 0...area.height)
        for (x in 0...area.width)
          if (cells[x][y] == TEMP_BUILDING)
            {
              var b = markBlock(area, x, y);
              if (b != null)
                blocks.add(b);
            }

      // fill blocks with content
      for (b in blocks)
        generateBlock(area, info, b);

      // convert temp tiles to correct
      var conv = [
        TEMP_ROAD => Const.TILE_ROAD,
        TEMP_ALLEY => Const.TILE_ALLEY,
        TEMP_BLOCK => Const.TILE_WALKWAY,
        TEMP_ACTUAL_BUILDING => Const.TILE_BUILDING,
      ];
      for (y in 0...area.height)
        for (x in 0...area.width)
          cells[x][y] = conv[cells[x][y]];

      // crosswalks
      for (y in 0...area.height)
        for (x in 0...area.width)
          {
            if (area.getCellType(x, y) != Const.TILE_WALKWAY)
              continue;

            // find walkway corners
            var cnt = 0;
            for (i in 0...Const.dirx.length)
              if (area.getCellType(x + Const.dirx[i], y + Const.diry[i]) == Const.TILE_ROAD)
                cnt++;

            if (cnt < 5)
              continue;

            var roadDown = (area.getCellType(x, y - 1) == Const.TILE_WALKWAY);
            var roadRight = (area.getCellType(x - 1, y) == Const.TILE_WALKWAY);

            // get vertical crosswalk length 
            var yy = y;
            var len = 0;
            while (true)
              {
                yy = (roadDown ? yy + 1 : yy - 1);
                if (area.getCellType(x, yy) != Const.TILE_ROAD)
                  break;
                len++;
              }

            // good corner for vertical road
            if (len <= 5)
              {
                var yy = y;
                while (true)
                  {
                    yy = (roadDown ? yy + 1 : yy - 1);
                    if (area.getCellType(x, yy) != Const.TILE_ROAD)
                      break;
                    area.setCellType(x, yy, Const.TILE_CROSSWALKV);
                  }
              }

            // get horizontal crosswalk length 
            var xx = x;
            var len = 0;
            while (true)
              {
                xx = (roadRight ? xx + 1 : xx - 1);
                if (area.getCellType(xx, y) != Const.TILE_ROAD)
                  break;
                len++;
              }

            // good corner for horizontal road
            if (len <= 5)
              {
                var xx = x;
                while (true)
                  {
                    xx = (roadRight ? xx + 1 : xx - 1);
                    if (area.getCellType(xx, y) != Const.TILE_ROAD)
                      break;
                    area.setCellType(xx, y, Const.TILE_CROSSWALKH);
                  }
              }
          }

      // generate debris
      placeStreetDebris(area, cells);
    }

// generate objects on city block
  public function generateObjects(state: _GeneratorState, area: AreaGame, info: AreaInfo)
    {
      // spawn sewers
      var spawned = new List();
      for (pt in state.sewers)
        if (Std.random(100) < 20)
          {
            // check if road or walkway
            var c = area.getCellType(pt.x, pt.y);
            if (c != Const.TILE_ROAD &&
                c != Const.TILE_WALKWAY)
              continue;

            // check for close objects
            var ok = true;
            for (old in spawned)
              if (Const.distanceSquared(pt.x, pt.y, old.x, old.y) < 8 * 8)
                {
                  ok = false;
                  break;
                }
            if (!ok)
              continue;

            var o = new SewerHatch(game, area.id, pt.x, pt.y);
            spawned.add(pt);
            area.addObject(o);
          }
    }

// generate street debris tuned by city tier
  function placeStreetDebris(area: AreaGame, cells: Array<Array<Int>>)
    {
      for (y in 0...area.height)
        for (x in 0...area.width)
          {
            var tile = cells[x][y];
            if (!isStreetTile(tile))
              continue;
            if (area.hasObjectAt(x, y))
              continue;

            var chance = debrisChanceFor(area, tile);
            if (chance <= 0)
              continue;
            if (Std.random(1000) >= chance)
              continue;

            if (Std.random(100) < 60)
              addDecorationTransformable(area, x, y, Const.STREET_DEBRIS_TRANSFORMABLE);
            else
              addStaticStreetDebris(area, x, y, Const.STREET_DEBRIS_STATIC);
          }
    }

// drop a transformable decoration and optionally scatter nearby debris
  function addDecorationTransformable(area: AreaGame,
      x: Int, y: Int, infos: Array<_TileRow>)
    {
      var centerCount = 3 + Std.random(2);
      // add burning barrel
      if (Std.random(100) < 20 &&
          area.typeID == AREA_CITY_LOW)
        {
          var o = new Decoration(game, area.id, x, y,
            Const.ROW_OBJECT2,
            Const.FRAME_BURNING_BARREL);
          area.addObject(o);
          // change to unwalkable tile
          gen.makeTileUnwalkable(area, x, y);
        }
      else spawnTransformableDecorations(area, x, y, infos, centerCount);

      var radius = 1 + Std.random(2);
      for (dx in -radius...radius + 1)
        for (dy in -radius...radius + 1)
          {
            if (dx == 0 && dy == 0)
              continue;
            if ((dx * dx + dy * dy) > radius * radius)
              continue;
            if (Std.random(100) >= 40)
              continue;

            var nx = x + dx;
            var ny = y + dy;
            if (nx < 0 || ny < 0 || nx >= area.width || ny >= area.height)
              continue;
            if (area.hasObjectAt(nx, ny))
              continue;

            var tile = area.getCellType(nx, ny);
            if (!isStreetTile(tile))
              continue;

            var neighbourCount = 1 + Std.random(4);
            if (area.typeID != AREA_CITY_LOW)
              neighbourCount += 1 + Std.random(2);
            spawnTransformableDecorations(area, nx, ny, infos, neighbourCount);
          }
    }

// add one static debris decoration to tile storage
  function addStaticStreetDebris(area: AreaGame, x: Int, y: Int,
      infos: Array<_TileRow>)
    {
      addStreetDebris(area, x, y, infos, false);
    }

// pick random sprites from infos and drop amount of tile decorations
  function spawnTransformableDecorations(area: AreaGame,
      x: Int, y: Int, infos: Array<_TileRow>, amount: Int)
    {
      for (_ in 0...amount)
        addStreetDebris(area, x, y, infos, true);
    }

// add one debris decoration entry with optional transform and spillover
  function addStreetDebris(area: AreaGame, x: Int, y: Int,
      infos: Array<_TileRow>, isTransformable: Bool)
    {
      if (!area.isWalkable(x, y))
        return;

      var info = infos[Std.random(infos.length)];
      var col = Std.random(info.amount) +
        (info.col != null ? info.col : 0);

      var scale = (isTransformable ?
        Const.round2(0.1 + 0.9 * Math.random()) :
        1.0);
      var angle = (isTransformable ?
        Const.round2(360 * Math.random() * Math.PI / 180) :
        0.0);
      var dx = 0;
      var dy = 0;

      var hasPlacement = false;
      for (_ in 0...8)
        {
          var candidateDX = randomDebrisOffset();
          var candidateDY = randomDebrisOffset();
          if (!canPlaceDebrisWithOffset(area, x, y,
                candidateDX, candidateDY, scale))
            continue;
          dx = candidateDX;
          dy = candidateDY;
          hasPlacement = true;
          break;
        }
      if (!hasPlacement &&
          !canPlaceDebrisWithOffset(area, x, y, 0, 0, scale))
        return;

      area.addTileDecoration(x, y, {
        layerID: Default.STREET_DEBRIS_LAYER_ID,
        icon: {
          row: info.row,
          col: col,
        },
        dx: dx,
        dy: dy,
        scale: scale,
        angle: angle,
      });
    }

// get random tile-local offset in +/-50% tile range
  function randomDebrisOffset(): Int
    {
      var half = Std.int(Const.TILE_SIZE / 2);
      return -half + Std.random(half * 2 + 1);
    }

// check whether transformed debris stays on walkable neighbouring tiles
  function canPlaceDebrisWithOffset(area: AreaGame, x: Int, y: Int,
      dx: Int, dy: Int, scale: Float): Bool
    {
      if (!area.isWalkable(x, y))
        return false;

      var scaledSize = Const.TILE_SIZE * scale;
      var localX1 = Const.TILE_SIZE / 2 -
        scaledSize / 2 + dx;
      var localY1 = Const.TILE_SIZE / 2 -
        scaledSize / 2 + dy;
      var localX2 = localX1 + scaledSize;
      var localY2 = localY1 + scaledSize;

      var touchesLeft = localX1 < 0;
      var touchesRight = localX2 > Const.TILE_SIZE;
      var touchesTop = localY1 < 0;
      var touchesBottom = localY2 > Const.TILE_SIZE;

      if (touchesLeft &&
          !area.isWalkable(x - 1, y))
        return false;
      if (touchesRight &&
          !area.isWalkable(x + 1, y))
        return false;
      if (touchesTop &&
          !area.isWalkable(x, y - 1))
        return false;
      if (touchesBottom &&
          !area.isWalkable(x, y + 1))
        return false;

      if (touchesLeft &&
          touchesTop &&
          !area.isWalkable(x - 1, y - 1))
        return false;
      if (touchesRight &&
          touchesTop &&
          !area.isWalkable(x + 1, y - 1))
        return false;
      if (touchesLeft &&
          touchesBottom &&
          !area.isWalkable(x - 1, y + 1))
        return false;
      if (touchesRight &&
          touchesBottom &&
          !area.isWalkable(x + 1, y + 1))
        return false;

      return true;
    }

// resolve debris spawn chance for a tile type given area tier (out of 1000)
  inline function debrisChanceFor(area: AreaGame, tile: Int): Int
    {
      var isRoad = (tile == Const.TILE_ROAD);
      return switch (area.typeID)
        {
          case AREA_CITY_LOW:
            if (area.highCrime)
              return (isRoad ? 30 : 50);
            else return (isRoad ? 10 : 20);
          case AREA_CITY_MEDIUM:
            isRoad ? 10 : 20;
          case AREA_CITY_HIGH:
            isRoad ? 2 : 5;
          default:
            isRoad ? 10 : 20;
        };
    }

// find the rectangular TEMP block starting at bx,by and mark it consumed
  function markBlock(area: AreaGame, bx: Int, by: Int): _Block
    {
      var cells = area.getCells();
      var sx = bx;
      var sy = by;
      var xx = bx;
      while (xx++ < area.width - 1)
        {
          if (cells[xx][sy] != TEMP_BUILDING)
            break;
        }
      var w = xx - sx;
      var yy = by;
      while (yy++ < area.height - 1)
        {
          if (cells[sx][yy] != TEMP_BUILDING)
            break;
        }
      var h = yy - sy;

      var block: _Block = {
        x1: sx,
        y1: sy,
        x2: sx + w,
        y2: sy + h,
        w: w,
        h: h
      };

      for (yy in sy...sy + h)
        for (xx in sx...sx + w)
          cells[xx][yy] = TEMP_BLOCK;

      return block;
    }

// populate a marked block with random buildings and inner courtyards
  function generateBlock(area: AreaGame, info: AreaInfo, block: _Block)
    {
      for (y in block.y1 + 1...block.y2)
        for (x in block.x1 + 1...block.x2)
          {
            if (Std.random(100) > 30)
              continue;

            var sx = 6 + 2 * Std.random(info.buildingSize);
            var sy = 6 + 2 * Std.random(info.buildingSize);

            if (x + sx > block.x2 - 1)
              sx = block.x2 - 1 - x;
            if (y + sy > block.y2 - 1)
              sy = block.y2 - 1 - y;

            if (sx < 4)
              continue;
            if (sy < 4)
              continue;

            var ok = true;
            for (dy in -2...sy + 3)
              for (dx in -2...sx + 3)
                {
                  if (dx == 0 && dy == 0)
                    continue;
                  var cellType = area.getCellType(x + dx, y + dy);
                  if (cellType == TEMP_ACTUAL_BUILDING)
                    {
                      ok = false;
                      break;
                    }
                }

            if (!ok)
              continue;

            for (dy in 0...sy)
              for (dx in 0...sx)
                {
                  var cellType = area.getCellType(x + dx, y + dy);
                  if (cellType == -1)
                    continue;

                  area.setCellType(x + dx, y + dy, TEMP_ACTUAL_BUILDING);
                }

            if (sx > 6 && sy > 6)
              {
                var hw = Std.int(sx / 2);
                var hh = Std.int(sy / 2);
                var hx = Std.random(sx - hw);
                var hy = Std.random(sy - hh);
                if (hx > 0 && hy > 0)
                  {
                    if (Std.random(100) < 50)
                      hx = 0;
                    else hy = 0;

                  }
                if (hx > 0 && hx < 4)
                  hx = 4;
                if (hy > 0 && hy < 4)
                  hy = 4;
                if (sx - hx - hw < 4)
                  hw = sx - hx;
                if (sy - hy - hh < 4)
                  hh = sy - hy;

                if (Std.random(100) < 50)
                  {
                    if (hx == 0)
                      hx = sx - hw;
                    else if (hy == 0)
                      hy = sy - hh;
                  }

                for (dy in hy...hy + hh)
                  for (dx in hx...hx + hw)
                    area.setCellType(x + dx, y + dy, TEMP_BLOCK);
              }
          }
    }

// carve out a narrow alley starting from a spawn point
  function addAlley(area: AreaGame, pt, w: Int)
    {
      var cells = area.getCells();

      var count = countAround(area, cells, pt.x, pt.y, TEMP_ROAD);
      if (count > 3)
        return;

      if (blockCount(area, cells, pt.x - 8, pt.y - 8, TEMP_ROAD, 16) > 100)
        return;

      if (blockHas(area, cells, pt.x - 8, pt.y - 8, TEMP_ALLEY, 16))
        return;

      var x = pt.x;
      var y = pt.y;
      var dir = pt.t;

      var len = 0;
      var xx = x;
      var yy = y;

      var dirChanged = 0;
      while (true)
        {
          fillBlock(area, cells, xx, yy, TEMP_ALLEY, w);

          var dx = 0;
          var dy = 0;
          if (dir == TB)
            dy = w;
          else if (dir == BT)
            dy = -w;
          else if (dir == LR)
            dx = w;
          else if (dir == RL)
            dx = -w;

          if (xx + dx < 0 || yy + dy < 0 ||
              xx + dx >= area.width || yy + dy >= area.height)
            break;

          xx += dx;
          yy += dy;
          len++;

          if (blockHas(area, cells, xx, yy, TEMP_ROAD, w) ||
              blockHas(area, cells, xx, yy, TEMP_ALLEY, w)) 
            break;

          if (len > 100)
            break;
        }
    }

// extend a street in the given direction, spawning alleys and sewers on the way
  function addStreet(state: _GeneratorState, area: AreaGame, cells: Array<Array<Int>>,
      dir: _LineDir, sx: Int, sy: Int, level: Int)
    {
      var i = 0;
      var xx = sx;
      var yy = sy;
      var w = 0;
      var toggle = false;
      var streetLevel = streetLevels[level];
      w = streetLevel.w;

      while (true) 
        {
          if (xx > area.width || yy > area.height)
            break;

          if (dir == LR && xx > 0 && xx % state.blockSize == 0) 
            {
              if (level > 0 && Std.random(100) < 25)
                {
                  fillBlock(area, cells, xx, yy, TEMP_ROAD, w);

                  break;
                }
            }

          if (level > 0 && dir == TB &&
              blockHas(area, cells, xx, yy, TEMP_ROAD, w))
            {
              if (Std.random(100) < 10)
                {
                  fillBlock(area, cells, xx, yy, TEMP_ROAD, w);
                  break;
                }
            }

          fillBlock(area, cells, xx, yy, TEMP_ROAD, w);

          var dx = 0;
          var dy = 0;
          if (dir == TB)
            dy = w;
          else if (dir == BT)
            dy = -w;
          else if (dir == LR)
            dx = w;
          else if (dir == RL)
            dx = -w;

          if (xx + dx < 0 || yy + dy < 0 ||
              xx + dx >= area.width || yy + dy >= area.height)
            {
              fillBlock(area, cells, xx + dx, yy + dy, TEMP_ROAD, w);
              break;
            }

          var bs = 8;
          if (dir == TB &&
              ((yy - sy - w) % bs == 0) &&
              yy != sy)
            {
              state.alleys.add({
                x: xx - 2,
                y: yy,
                t: RL
              });
              state.alleys.add({
                x: xx + w,
                y: yy,
                t: LR
              });
            }
          else if (dir == LR &&
              ((xx - sx - w) % bs == 0) &&
              xx != sx)
            {
              state.alleys.add({
                x: xx,
                y: yy - 2,
                t: BT
              });
              state.alleys.add({
                x: xx,
                y: yy + w,
                t: TB
              });
            }

          var bs2 = 4;
          if (dir == TB &&
              ((yy - sy - w) % bs2 == 0) &&
              yy != sy)
            {
              if (area.getCellType(xx - 1, yy) != TEMP_ROAD)
                state.sewers.add({ x: xx - 1, y: yy });
              if (area.getCellType(xx + w, yy) != TEMP_ROAD)
                state.sewers.add({ x: xx + w, y: yy });
              state.sewers.add({
                x: xx + streetLevel.half + (toggle ? -1 : 0), y: yy });
            }
          else if (dir == LR &&
              ((xx - sx - w) % bs2 == 0) &&
              xx != sx)
            {
              if (area.getCellType(xx, yy - 1) != TEMP_ROAD)
                state.sewers.add({ x: xx, y: yy - 1 });
              if (area.getCellType(xx, yy + w) != TEMP_ROAD)
                state.sewers.add({ x: xx, y: yy + w });
              state.sewers.add({
                x: xx, y: yy + streetLevel.half + (toggle ? -1 : 0) });
            }

          xx += dx;
          yy += dy;
          toggle = !toggle;

          i++;
        }
    }

// count how many neighbours around x,y match the tile id t
  function countAround(area: AreaGame, cells: Array<Array<Int>>,
      x: Int, y: Int, t: Int): Int
    {
      var cnt = 0;
      var xx = 0;
      var yy = 0;
      for (i in 0...Const.dirx.length)
        {
          xx = x + Const.dirx[i];
          yy = y + Const.diry[i];

          if (xx >= 0 && yy >= 0 && xx < area.width && yy < area.height)
            {
              if (cells[xx][yy] == t)
                cnt++;
            }
        }

      return cnt;
    }

// check if tile id represents a street-surface tile
  inline function isStreetTile(tile: Int): Bool
    {
      return tile == Const.TILE_ROAD ||
        tile == Const.TILE_ALLEY ||
        tile == Const.TILE_WALKWAY;
    }

// fill a square block of width w with tile t, clamped to bounds
  function fillBlock(area: AreaGame, cells: Array<Array<Int>>,
      x: Int, y: Int, t: Int, w: Int)
    {
      for (yy in y...y + w)
        for (xx in x...x + w)
          if (xx >= 0 && yy >= 0 && xx < area.width && yy < area.height)
            cells[xx][yy] = t;
    }

// return true if any tile within the block equals t
  function blockHas(area: AreaGame, cells: Array<Array<Int>>,
      x: Int, y: Int, t: Int, w: Int): Bool
    {
      for (yy in y...y + w)
        for (xx in x...x + w)
          if (xx >= 0 && yy >=0 && xx < area.width && yy < area.height && cells[xx][yy] == t)
            return true;

      return false;
    }

// count tiles equal to t inside the w-by-w block
  function blockCount(area: AreaGame, cells: Array<Array<Int>>,
      x: Int, y: Int, t: Int, w: Int): Int
    {
      var cnt = 0;
      for (yy in y...y + w)
        for (xx in x...x + w)
          if (xx >= 0 && yy >=0 && xx < area.width && yy < area.height && cells[xx][yy] == t)
            cnt++;

      return cnt;
    }

  static var streetLevels = [
    { w: 8, blockSize: 20, half: 4 },
    { w: 4, blockSize: 16, half: 2 },
  ];

  public static var TEMP_BUILDING = 0;
  public static var TEMP_ROAD = 1;
  public static var TEMP_ALLEY = 2;
  public static var TEMP_ALLEY_TB = 3;
  public static var TEMP_ALLEY_BT = 4;
  public static var TEMP_ALLEY_LR = 5;
  public static var TEMP_ALLEY_RL = 6;
  public static var TEMP_ACTUAL_BUILDING = 7;
  public static var TEMP_WALKWAY = 8;
  public static var TEMP_BLOCK = 9;
  public static var TEMP_MARKER = 10;
}
