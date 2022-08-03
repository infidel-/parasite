// area generation

package game;

import const.WorldConst;
import objects.*;
import game.AreaGame;

class AreaGenerator
{
  public var game: Game;

  public function new(g: Game)
    {
      game = g;
    }

// generate area
  public function generate(area: AreaGame, info: AreaInfo)
    {
      var state: _GeneratorState = {
        alleys: new List(),
        sewers: new List(),
        blockSize: 20,
      };

      if (info.type == 'city')
        generateCity(state, game, area, info);
      else if (info.type == 'militaryBase')
        generateBuildings(game, area, info);
      else if (info.type == 'facility')
        FacilityAreaGenerator.generate(game, area, info);
      else if (info.type == 'wilderness')
        generateWilderness(game, area, info);
      else if (info.type == 'habitat')
        generateHabitat(game, area, info);
      else trace('AreaGenerator.generate(): unknown area type: ' + info.type);

      if (info.type == 'city')
        generateObjectsCity(state, game, area, info);
      else generateObjects(state, game, area, info);

/*
      // draw map
      var map = new h2d.Graphics();
      var scale = 4;
      map.x = 0;
      map.y = 0;
      map.clear();
      map.beginFill(0, 1);
      map.drawRect(0, 0, area.width * (scale + 1),
        area.height * (scale + 1));

      var cells = area.getCells();
      var cols1 = [
        TEMP_BUILDING => 0x22ff22,
        TEMP_ROAD => 0x222222, // dark grey
        TEMP_ALLEY => 0x666666,
        TEMP_ALLEY_TB => 0xffff44,
        TEMP_ALLEY_BT => 0x44ffff,
        TEMP_ALLEY_LR => 0xff44ff,
        TEMP_ALLEY_RL => 0x4444ff,
        TEMP_MARKER => 0xffffff,
        TEMP_ACTUAL_BUILDING => 0xff6666, // pink
        TEMP_WALKWAY => 0x6666ff,
        TEMP_BLOCK => 0x00ffff,
      ];

      var cols = [
        Const.TILE_ROAD => cols1[TEMP_ROAD],
        Const.TILE_ALLEY => cols1[TEMP_ALLEY],
        Const.TILE_WALKWAY => cols1[TEMP_BLOCK],
        Const.TILE_BUILDING => cols1[TEMP_ACTUAL_BUILDING],
      ];
      for (y in 0...area.height)
        {
          for (x in 0...area.width)
            {
              map.beginFill(cols1[cells[x][y]], 1);
              map.drawRect(x * (scale + 1), y * (scale + 1), scale, scale);
            }
        }
      map.endFill();
      game.scene.add(map, 100);
*/
    }

// print generated area tiles 
  public static function printArea(game: Game, area: AreaGame, mapTiles: Array<String>)
    {
      var cells = area.getCells();
      var s = 'XX: ';
      for (i in 0...Std.int(cells.length / 10))
        s += '|123456789';
      js.Browser.console.log(s);
      var list = '';
      var lastRoomID = 0;
      for (y in 0...area.height)
        {
          var s = '';
          var tileID = 0;
          for (x in 0...area.width)
            {
              tileID = cells[x][y];
              var char = mapTiles[cells[x][y]];
              s += (char != null ? char : '?');
/*
              // room IDs after
              if (tileID < 100)
                {
                  var char = mapTiles[cells[x][y]];
                  s += (char != null ? char : '?');
                }
              else
                {
                  var char = String.fromCharCode(tileID - 100 + 97);
                  if (lastRoomID < tileID)
                    {

                      list += char + ': ' + tileID + ', ';
                      lastRoomID = tileID;
                    }
                  s += char;
                }*/
            }
          js.Browser.console.log((y < 10 ? '0' : '') + y + ': ' + s);
        }
      js.Browser.console.log(list);
    }

// generate a city block
  static function generateCity(state: _GeneratorState, game: Game, area: AreaGame, info: AreaInfo)
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

      return;
/*
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
*/
    }


// find a rectangular block and fill it with actual buildings
  static function markBlock(area: AreaGame, bx: Int, by: Int): _Block
    {
      // find block dimensions
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

      // mark (for next blocks)
      for (yy in sy...sy + h)
        for (xx in sx...sx + w)
          cells[xx][yy] = TEMP_BLOCK;

      return block;
    }


// fill block with buildings
  static function generateBlock(area: AreaGame, info: AreaInfo, block: _Block)
    {
//      trace('block: ' + block);

      // buildings
      for (y in block.y1 + 1...block.y2)
        for (x in block.x1 + 1...block.x2)
          {
            if (Std.random(100) > 30)
              continue;

            // size
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

            // check for adjacent buildings (may go out of bounds)
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
  
            // draw a building rect
            for (dy in 0...sy)
              for (dx in 0...sx)
                {
                  var cellType = area.getCellType(x + dx, y + dy);
                  if (cellType == -1)
                    continue;

                  area.setCellType(x + dx, y + dy, TEMP_ACTUAL_BUILDING);
                }

            // large buildings can have a hole in them
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

                // move hole to other sides
                if (Std.random(100) < 50)
                  {
                    if (hx == 0)
                      hx = sx - hw;
                    else if (hy == 0)
                      hy = sy - hh;
                  }

                // cut hole
                for (dy in hy...hy + hh)
                  for (dx in hx...hx + hw)
                    area.setCellType(x + dx, y + dy, TEMP_BLOCK);
              }
          }
    }


// add alley
  static function addAlley(area: AreaGame, pt, w: Int)
    {
      var cells = area.getCells();

      var count = countAround(area, cells, pt.x, pt.y, TEMP_ROAD);
      if (count > 3)
        return;

      // check roads near
      if (blockCount(area, cells, pt.x - 8, pt.y - 8, TEMP_ROAD, 16) > 100)
        return;

      // check alleys near
      if (blockHas(area, cells, pt.x - 8, pt.y - 8, TEMP_ALLEY, 16))
        return;

      // find starting direction
      var x = pt.x;
      var y = pt.y;
      var dir = pt.t;

      var len = 0;
      var xx = x;
      var yy = y;

      var dirChanged = 0;
      while (true)
        {
          // mark block as alley
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


// add main street with branches (recursive)
  static var streetLevels = [
    { w: 8, blockSize: 20, half: 4 },
    { w: 4, blockSize: 16, half: 2 },
  ];
  static function addStreet(state: _GeneratorState, area: AreaGame, cells: Array<Array<Int>>,
      dir: _LineDir, sx: Int, sy: Int,
      level: Int)
    {
      var i = 0;
      var xx = sx;
      var yy = sy;
      var w = 0;
      var toggle = false;
      var streetLevel = streetLevels[level];
      w = streetLevel.w;
//      trace(level + ': addStreet ' + dir + ', start:' + sx + ',' + sy +
//        ', w:' + w + ', bs: ' + streetLevel.blockSize);

      while (true) 
        {
          // out of bounds
          if (xx > area.width || yy > area.height)
            break;

          // horizontal road can stop on edge of block
          if (dir == LR && xx > 0 && xx % state.blockSize == 0) 
            {
              if (level > 0 && Std.random(100) < 25)
                {
                  // mark last block as road
                  fillBlock(area, cells, xx, yy, TEMP_ROAD, w);

                  break;
                }
            }

          // vertical road can stop when hitting another road
          if (level > 0 && dir == TB &&
              blockHas(area, cells, xx, yy, TEMP_ROAD, w))
            {
              if (Std.random(100) < 10)
                {
                  // mark last block as road
                  fillBlock(area, cells, xx, yy, TEMP_ROAD, w);
                  break;
                }
            }

          // mark block as road
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
              // last block, partially off-area
              fillBlock(area, cells, xx + dx, yy + dy, TEMP_ROAD, w);
              break;
            }

          // alley spawn points
          var bs = 8;
          if (dir == TB &&
              ((yy - sy - w) % bs == 0) &&
              yy != sy)
            {
//              fillBlock(area, cells, xx - 2, yy, TEMP_ALLEY_RL, 1);
//              fillBlock(area, cells, xx + w, yy, TEMP_ALLEY_LR, 1);
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
//              fillBlock(area, cells, xx, yy - 2, TEMP_ALLEY_BT, 1);
//              fillBlock(area, cells, xx, yy + w, TEMP_ALLEY_TB, 1);
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

          // sewer spawn points
          var bs = 4;
          if (dir == TB &&
              ((yy - sy - w) % bs == 0) &&
              yy != sy)
            {
              if (area.getCellType(xx - 1, yy) != TEMP_ROAD)
//                fillBlock(area, cells, xx - 1, yy, TEMP_MARKER, 1);
                state.sewers.add({ x: xx - 1, y: yy });
              if (area.getCellType(xx + w, yy) != TEMP_ROAD)
//                fillBlock(area, cells, xx + w, yy, TEMP_MARKER, 1);
                state.sewers.add({ x: xx + w, y: yy });
//              fillBlock(area, cells,
//                xx + streetLevel.half + (toggle ? -1 : 0), yy, TEMP_MARKER, 1);
              state.sewers.add({
                x: xx + streetLevel.half + (toggle ? -1 : 0), y: yy });
/*
              state.alleys.add({
                x: xx - 1,
                y: yy,
                t: RL
              });
              state.alleys.add({
                x: xx + w,
                y: yy,
                t: LR
              });
*/
            }
          else if (dir == LR &&
              ((xx - sx - w) % bs == 0) &&
              xx != sx)
            {
              if (area.getCellType(xx, yy - 1) != TEMP_ROAD)
//                fillBlock(area, cells, xx, yy - 1, TEMP_MARKER, 1);
                state.sewers.add({ x: xx, y: yy - 1 });
              if (area.getCellType(xx, yy + w) != TEMP_ROAD)
//                fillBlock(area, cells, xx, yy + w, TEMP_MARKER, 1);
                state.sewers.add({ x: xx, y: yy + w });
//              fillBlock(area, cells,
//                xx, yy + streetLevel.half + (toggle ? -1 : 0), TEMP_MARKER, 1);
              state.sewers.add({
                x: xx, y: yy + streetLevel.half + (toggle ? -1 : 0) });
/*
              state.alleys.add({
                x: xx,
                y: yy - 1,
                t: BT
              });
              state.alleys.add({
                x: xx,
                y: yy + w,
                t: TB
              });
*/
            }

          xx += dx;
          yy += dy;
          toggle = !toggle;

          i++;
        }
    }


// count amount of cells of this type around given
  static function countAround(area: AreaGame, cells: Array<Array<Int>>,
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


// fill a square block with tile
  static function fillBlock(area: AreaGame, cells: Array<Array<Int>>,
      x: Int, y: Int, t: Int, w: Int)
    {
      for (yy in y...y + w)
        for (xx in x...x + w)
          if (xx >= 0 && yy >= 0 && xx < area.width && yy < area.height)
            cells[xx][yy] = t;
    }


// check if a square block has this tile
  static function blockHas(area: AreaGame, cells: Array<Array<Int>>,
      x: Int, y: Int, t: Int, w: Int): Bool
    {
      for (yy in y...y + w)
        for (xx in x...x + w)
          if (xx >= 0 && yy >=0 && xx < area.width && yy < area.height && cells[xx][yy] == t)
            return true;

      return false;
    }


// count number of X tiles in a square block
  static function blockCount(area: AreaGame, cells: Array<Array<Int>>,
      x: Int, y: Int, t: Int, w: Int): Int
    {
      var cnt = 0;
      for (yy in y...y + w)
        for (xx in x...x + w)
          if (xx >= 0 && yy >=0 && xx < area.width && yy < area.height && cells[xx][yy] == t)
            cnt++;

      return cnt;
    }


// generate a habitat
  static function generateHabitat(game: Game, area: AreaGame, info: AreaInfo)
    {
      // fill with walls
      for (y in 0...area.height)
        for (x in 0...area.width)
          area.setCellType(x, y, Const.TILE_WALL);

      // make some rooms
      for (i in 0...10)
        {
          var x1 = 1 + Std.random(area.width - 5);
          var y1 = 1 + Std.random(area.height - 5);
          var w = 5 + Std.random(15);
          var h = 5 + Std.random(15);
          if (x1 + w >= area.width - 1)
            w = area.width - x1 - 2;
          if (y1 + h >= area.height - 1)
            h = area.height - y1 - 2;
          makeRoom(area, x1, y1, w, h);
        }
    }


// helper: make a room
  static function makeRoom(area: AreaGame, x1: Int, y1: Int, w: Int, h: Int)
    {
      for (y in y1...y1 + h)
        for (x in x1...x1 + w)
          area.setCellType(x, y, Const.TILE_WALKWAY);
    }


// generate rocks, trees, etc
  static function generateWilderness(game: Game, area: AreaGame, info: AreaInfo)
    {
      var numStuff = Std.int(area.width * area.height / 20);
      for (i in 0...numStuff)
        {
          var x = Std.random(area.width);
          var y = Std.random(area.height);

          var t = Const.TILE_BUSH;
          if (Std.random(100) < 30)
            t = Const.TILE_ROCK;
          if (Std.random(100) < 30)
            t = Const.TILE_TREE1 +
              Std.random(Const.TILE_BUSH - Const.TILE_TREE1);

          area.setCellType(x, y, t);
        }
    }


// generate buildings
  static function generateBuildings(game: Game, area: AreaGame, info: AreaInfo)
    {
      // buildings
      for (y in 1...area.height)
        for (x in 1...area.width)
          {
            if (Math.random() > info.buildingChance)
              continue;

            // size
            var sx = 5 + Std.random(10);
            var sy = 5 + Std.random(10);

            if (x + sx > area.width - 1)
              sx = area.width - 1 - x;
            if (y + sy > area.height - 1)
              sy = area.height - 1 - y;

            if (sx < 2)
              continue;
            if (sy < 2)
              continue;

//            var cell = get(x,y);

            // check for adjacent buildings
            var ok = true;
            for (dy in -2...sy + 3)
              for (dx in -2...sx + 3)
                {
                  if (dx == 0 && dy == 0)
                    continue;
                  //var cell = get(x + dx, y + dy);
                  var cellType = area.getCellType(x + dx, y + dy);
                  if (cellType == Const.TILE_BUILDING)
                    {
                      ok = false;
                      break;
                    }
                }

            if (!ok)
              continue;
  
            // draw a building rect
            for (dy in 0...sy)
              for (dx in 0...sx)
                {
                  var cellType = area.getCellType(x + dx, y + dy);
                  if (cellType == -1)
                    continue;

                  area.setCellType(x + dx, y + dy, Const.TILE_BUILDING);
                }
          }
    }


// generate objects
  static function generateObjects(state: _GeneratorState, game: Game, area: AreaGame, info: AreaInfo)
    {
      // spawn all objects
      for (objInfo in info.objects)
        for (i in 0...objInfo.amount)
          {
            // find free spot that is not close to another object like this
            var loc = null;
            var cnt = 0;
            while (true)
              {
                loc = area.findEmptyLocation();
                cnt++;
                if (cnt > 500)
                  {
                    trace('Area.generateObjects(): no free spot for another ' + 
                      objInfo.id + ', please report');
                    return;
                  }

                // check for close objects
                var ok = true;
                for (y in -3...3)
                  for (x in -3...3)
                    {
                      var olist = area.getObjectsAt(loc.x + x, loc.y + y);
                      for (o in olist)
                        if (o.type == objInfo.id)
                          {
                            ok = false;
                            break;
                          }

                      if (!ok)
                        break;
                    }

                if (ok)
                  break;
              }

            var o: AreaObject = null;
            if (objInfo.id == 'sewer_hatch')
              o = new SewerHatch(game, area.id, loc.x, loc.y);
              
            else throw 'unknown object type: ' + objInfo.id;

            area.addObject(o);
          }
    }


// generate objects on city block
  static function generateObjectsCity(state: _GeneratorState, game: Game, area: AreaGame, info: AreaInfo)
    {
      // spawn sewers
      var spawned = new List();
      for (pt in state.sewers)
        if (Std.random(100) < 20)
          {
            // check if road or walkway
            var c = area.getCellType(pt.x, pt.y);
            if (c != Const.TILE_ROAD && c != Const.TILE_WALKWAY)
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

  static var TEMP_BUILDING = 0;
  static var TEMP_ROAD = 1;
  static var TEMP_ALLEY = 2;
  static var TEMP_ALLEY_TB = 3;
  static var TEMP_ALLEY_BT = 4;
  static var TEMP_ALLEY_LR = 5;
  static var TEMP_ALLEY_RL = 6;
  static var TEMP_ACTUAL_BUILDING = 7;
  static var TEMP_WALKWAY = 8;
  static var TEMP_BLOCK = 9;
  static var TEMP_MARKER = 10;
}


enum _LineDir
{
  TB;
  BT;
  LR;
  RL;
}


typedef _GeneratorState = {
  alleys: List<{
    x: Int,
    y: Int,
    t: _LineDir
  }>,
  sewers: List<{
    x: Int,
    y: Int,
  }>,
  blockSize: Int,
}


typedef _Block = {
  x1: Int,
  y1: Int,
  x2: Int,
  y2: Int,
  w: Int,
  h: Int,
}
