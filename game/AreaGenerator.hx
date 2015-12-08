// area generation

package game;

import const.WorldConst;
import objects.*;
import game.AreaGame;

class AreaGenerator
{
  public static function generate(game: Game, area: AreaGame, info: AreaInfo)
    {
      if (info.type == 'city')
        generateCity(game, area, info);
      else if (info.type == 'militaryBase')
        generateBuildings(game, area, info);
      else if (info.type == 'facility')
        generateBuildings(game, area, info);
      else if (info.type == 'wilderness')
        generateWilderness(game, area, info);
      else if (info.type == 'habitat')
        generateHabitat(game, area, info);
      else trace('AreaGenerator.generate(): unknown area type: ' + info.type);

/*
      var cells = area.getCells();
      for (y in 0...area.height)
        {
          for (x in 0...area.width)
            neko.Lib.print(cells[x][y]);
          neko.Lib.println('');
        }
*/
      var cells = area.getCells();
      for (y in 0...area.height)
        {
          for (x in 0...area.width)
            neko.Lib.print(cells[x][y] == Const.TILE_BUILDING ? 1 : 0);
          neko.Lib.println('');
        }
  //    Sys.exit(1);

      generateObjects(game, area, info);
    }


  static function addStreet(area: AreaGame, dir: _LineDir, sx: Int, sy: Int,
      level: Int)
    {
      var i = 0;
      var xx = sx;
      var yy = sy;

      var prevRoad = ((dir == TB || dir == BT) ? sy : sx);
      var w = 0;
      var maxlen = 200;
      if (level == 0)
        w = 10;
      else if (level == 1)
        {
          maxlen = 50;
          w = 5;
        }
      else if (level == 2)
        {
          maxlen = 25;
          w = 3;
        }
      else
        {
          maxlen = 15;
          w = 3;
        }

      while (true) 
        {
          for (i in 0...w)
            area.setCellType(xx + ((dir == TB || dir == BT) ? i : 0),
              yy + ((dir == LR || dir == RL) ? i : 0), Const.TILE_ROAD);

          if (i > maxlen && Std.random(100) > i && level > 0)
            break;

          var dx = 0;
          var dy = 0;
          if (dir == TB)
            dy = 1;
          else if (dir == BT)
            dy = -1;
          else if (dir == LR)
            dx = 1;
          else if (dir == RL)
            dx = -1;

          if (xx + dx < 0 || yy + dy < 0 ||
              xx + dx >= area.width || yy + dy >= area.height)
            break;

          var newRoad = (dx != 0 ? xx : yy);
          var blocksz = 10;
          if (level == 0)
            blocksz = 20;
          else if (level == 1)
            blocksz = 10;

          var newblock = ((newRoad - prevRoad) % 20) == 0;
          if (level < 3 && newRoad - prevRoad > 0 && newblock)
            {
              var newdir = null;
              if (dir == TB || dir == BT)
                newdir = Std.random(100) < 50 ? LR : RL;
              else if (dir == LR || dir == RL)
                newdir = Std.random(100) < 50 ? BT : TB;

              // new road starting x,y
              var rx = xx;
              var ry = yy;
              if (newdir == TB)
                ry += w;
              else if (newdir == BT)
                ry -= 1;
              if (newdir == LR)
                rx += w;
              else if (newdir == RL)
                rx -= 1;

              prevRoad == (dx != 0 ? xx : yy);
              addStreet(area, newdir, rx, ry, level + 1);
            }

          xx += dx;
          yy += dy;

          i++;
        }
    }


// generate a city block
  static function generateCity(game: Game, area: AreaGame, info: AreaInfo)
    {
      // fill with walls
      for (y in 0...area.height)
        for (x in 0...area.width)
          area.setCellType(x, y, Const.TILE_BUILDING);

      var blockSize = 20;
      var blockW = Std.int(area.width / blockSize);
      var blockH = Std.int(area.height / blockSize);
      var blockW4 = Std.int(area.width / blockSize / 4);
      var blockH4 = Std.int(area.height / blockSize / 4);
      var bx = blockW4 + Std.random(blockW - 1 - blockW4);
      var by = blockH4 + Std.random(blockH - 1 - blockH4);
      addStreet(area, TB, bx * blockSize, 0, 0);

      // add alleys
      var cells = area.getCells();
      var maxrange = 10;
      for (y in 0...area.height)
        {
          var x = 0;
          while (x < area.width)
            {
              // check if there's a road in range
              var minx = x - maxrange;
              if (minx < 0)
                minx = 0;
              var maxx = x + maxrange;
              if (maxx > area.width)
                maxx = area.width;

              var miny = y - maxrange;
              if (miny < 0)
                miny = 0;
              var maxy = y + maxrange;
              if (maxy > area.height)
                maxy = area.height;

              var roadNear = false;
              for (yy in miny...maxy)
                for (xx in minx...maxx)
                  if (cells[xx][yy] == Const.TILE_ROAD)
                    {
                      roadNear = true;
                      break;
                    }

              // road near, skip this
              if (roadNear)
                {
                  x += 10;
                  continue;
                }

              // build an alley in random direction
              var dir = (Std.random(100) > 50 ? LR : TB);
              var len = 0;
              var xx = x;
              var yy = y;
              area.setCellType(xx, yy, Const.TILE_ROAD);
              var dirChanged = 0;
              while (true) 
                {
                  var dx = 0;
                  var dy = 0;
                  if (dir == TB)
                    dy = 1;
                  else if (dir == BT)
                    dy = -1;
                  else if (dir == LR)
                    dx = 1;
                  else if (dir == RL)
                    dx = -1;

                  xx += dx;
                  yy += dy;
                  len++;

                  if (xx < 0 || yy < 0)
                    break;

                  if (xx >= area.width)
                    break;

                  if (yy >= area.height)
                    break;

                  if (cells[xx][yy] == Const.TILE_ROAD)
                    break;

                  area.setCellType(xx, yy, Const.TILE_ROAD);

                  // switch direction
                  if (len > 5 && len % 10 == 1 && Std.random(100) < 40 &&
                      dirChanged < 4)
                    {
                      if (dir == TB)
                        dir = (Std.random(100) > 50 ? LR : RL);
                      else if (dir == LR)
                        dir = (Std.random(100) > 50 ? BT : TB);
                      dirChanged++;
                    }

                  if (len > 100)
                    break;
                }

              x += 10;
            }
        }

      // walkways
      for (y in 0...area.height)
        for (x in 0...area.width)
          {
            if (area.getCellType(x, y) != Const.TILE_ROAD)
              continue;

            var ok = false;
            for (i in 0...Const.dirx.length)
              if (area.getCellType(x + Const.dirx[i], y + Const.diry[i]) == Const.TILE_BUILDING)
                {
                  ok = true;
                  break;
                }

            if (ok)
              area.setCellType(x, y, Const.TILE_WALKWAY);
          }

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
    }


// helper: draw street
//  static function drawVerticalStreet(area: AreaGame, x1: Int, y1: Int, )
  static function lineV(area: AreaGame, x: Int, y1: Int, y2: Int, w: Int, t: Int)
    {
      if (w > 1)
        for (xx in x...x + w)
          for (y in y1...y2)
            area.setCellType(xx, y, t);
      else
        for (y in y1...y2)
          area.setCellType(x, y, t);
    }


// helper: draw street
  static function lineH(area: AreaGame, x1: Int, x2: Int, y: Int, w: Int, t: Int)
    {
      if (w > 1)
        for (x in x1...x2)
          for (yy in y...y + w)
            area.setCellType(x, yy, t);
      else
        for (x in x1...x2)
          area.setCellType(x, y, t);
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
          area.setCellType(x, y, Const.TILE_GROUND);
    }


// generate rocks, trees, etc
  static function generateWilderness(game: Game, area: AreaGame, info: AreaInfo)
    {
      var numStuff = Std.int(area.width * area.height / 20);
      for (i in 0...numStuff)
        {
          var x = Std.random(area.width);
          var y = Std.random(area.height);

          area.setCellType(x, y,
            (Std.random(100) < 50 ? Const.TILE_ROCK : Const.TILE_TREE));
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
                  if (cellType == null)
                    continue;

                  area.setCellType(x + dx, y + dy, Const.TILE_BUILDING);
                }
          }
    }


// generate objects
  static function generateObjects(game: Game, area: AreaGame, info: AreaInfo)
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
              o = new SewerHatch(game, loc.x, loc.y);
              
            else throw 'unknown object type: ' + objInfo.id;

            area.addObject(o);
          }
    }
}


enum _LineDir
{
  TB;
  BT;
  LR;
  RL;
}
