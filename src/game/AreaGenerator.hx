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
//        generateCity(game, area, info);
        generateBuildings(game, area, info);
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
            Sys.print(cells[x][y]);
          Sys.println('');
        }
*/
/*
      var cells = area.getCells();
      for (y in 0...area.height)
        {
          for (x in 0...area.width)
//            Sys.print(cells[x][y] == Const.TILE_BUILDING ? 1 : 0);
            Sys.print(cells[x][y]);
          Sys.println('');
        }
*/
//      Sys.exit(1);

      generateObjects(game, area, info);
    }


  static function addAlley(area: AreaGame, x: Int, y: Int, w: Int)
    {
      var cells = area.getCells();
      var maxrange = (w == 1 ? 7 : 10);
/*
      // convert previous temp alley into normal alley
      for (yy in 0...area.height)
        for (xx in 0...area.width)
          if (cells[xx][yy] == TEMP_ALLEYTEMP)
            cells[xx][yy] = TEMP_ALLEY;
*/
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
          if (cells[xx][yy] == TEMP_ROAD || cells[xx][yy] == TEMP_ALLEY) //Const.TILE_ROAD)
            {
              roadNear = true;
              break;
            }

      // road near, skip this
      if (roadNear)
        return;

      // build an alley in random direction
      var dir = (Std.random(100) > 50 ? LR : TB);
      var len = 0;
      var xx = x;
      var yy = y;

      area.setCellType(xx, yy, TEMP_ALLEY); //Const.TILE_ROAD);
      for (j in 0...w)
        area.setCellType(xx + ((dir == TB || dir == BT) ? j : 0),
          yy + ((dir == LR || dir == RL) ? j : 0), TEMP_ALLEY); //Const.TILE_ROAD);

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

          if (cells[xx][yy] == TEMP_ROAD) //Const.TILE_ROAD)
            break;

          area.setCellType(xx, yy, TEMP_ALLEY); //Const.TILE_ROAD);
          for (j in 0...w)
            area.setCellType(xx + ((dir == TB || dir == BT) ? j : 0),
              yy + ((dir == LR || dir == RL) ? j : 0), TEMP_ALLEY); //Const.TILE_ROAD);

          // switch direction
          if (len > 5 && len % 10 == 2 && Std.random(100) < 40 &&
              dirChanged < 4)
            {
              if (dir == TB)
                {
                  dir = (Std.random(100) > 50 ? LR : RL);
                  yy--; // so that the turn will look good on width 2 alleys
                }
              else if (dir == LR)
                {
                  dir = (Std.random(100) > 50 ? BT : TB);
                  xx--;
                }
              dirChanged++;
            }

          if (len > 100)
            break;
        }
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
              yy + ((dir == LR || dir == RL) ? i : 0), TEMP_ROAD);//Const.TILE_ROAD);

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

  static var TEMP_BUILDING = 0;
  static var TEMP_ROAD = 1;
  static var TEMP_ALLEY = 2;
  static var TEMP_ALLEYTEMP = 3;
  static var TEMP_ACTUAL_BUILDING = 4;
  static var TEMP_WALKWAY = 5;


// generate a city block
  static function generateCity(game: Game, area: AreaGame, info: AreaInfo)
    {
/*
      var cells = new Array<Array<Int>>();
      for (i in 0...area.width)
        cells[i] = [];
*/
      var cells = area.getCells();
      // fill with walls
      for (y in 0...area.height)
        for (x in 0...area.width)
          cells[x][y] = TEMP_BUILDING; //Const.TILE_BUILDING);

      var blockSize = 20;
      var blockW = Std.int(area.width / blockSize);
      var blockH = Std.int(area.height / blockSize);
      var blockW4 = Std.int(area.width / blockSize / 4);
      var blockH4 = Std.int(area.height / blockSize / 4);
      var bx = blockW4 + Std.random(blockW - 1 - blockW4);
      var by = blockH4 + Std.random(blockH - 1 - blockH4);
      addStreet(area, TB, bx * blockSize, 0, 0);

      // add alleys w=2
      for (y in 0...area.height)
        {
          var x = 0;
          while (x < area.width)
            {
              addAlley(area, x, y, 2);

              x += 10;
            }
        }
/*
      // add alleys w=1
      for (y in 0...area.height)
        {
          var x = 0;
          while (x < area.width)
            {
              addAlley(area, x, y, 1);

              x += 5;
            var maxw = 10 + Std.random(5);
            }
        }
*/
      // smooth out 1-cell wide buildings
      for (y in 0...area.height)
        for (x in 0...area.width)
          {
            if (area.getCellType(x, y) != TEMP_BUILDING)
              continue;

            // continue vertical roads
            if (area.getCellType(x, y - 1) == TEMP_ROAD &&
                area.getCellType(x, y + 1) == TEMP_ROAD)
              area.setCellType(x, y, TEMP_ROAD);

            // continue horizontal roads
            if (area.getCellType(x - 1, y) == TEMP_ROAD &&
                area.getCellType(x + 1, y) == TEMP_ROAD)
              area.setCellType(x, y, TEMP_ROAD);

            // continue vertical alleys and connect roads to alleys
            if (area.getCellType(x, y - 1) != TEMP_BUILDING &&
                area.getCellType(x, y + 1) != TEMP_BUILDING)
              area.setCellType(x, y, TEMP_ALLEY);

            // continue horizontal alleys
            if (area.getCellType(x - 1, y) != TEMP_BUILDING &&
                area.getCellType(x + 1, y) != TEMP_BUILDING)
              area.setCellType(x, y, TEMP_ALLEY);
          }

      // make actual buildings from building cells
      for (y in 0...area.height)
        for (x in 0...area.width)
          {
            if (cells[x][y] != TEMP_BUILDING)
              continue;

            // find max w,h of new building (roughly)
            var maxx = 0;
            var maxy = 0;
            for (xx in x...area.width)
              if (cells[xx][y] != TEMP_BUILDING)
                {
                  maxx = xx;
                  break;
                }
            for (yy in y...area.height)
              if (cells[x][yy] != TEMP_BUILDING)
                {
                  maxy = yy;
                  break;
                }

            var w = maxx - x;
            var h = maxy - y;

            // max building size
            var maxw = 10 + Std.random(5);
            var maxh = 10 + Std.random(5);
            if (w > maxw)
              {
                w = maxw;
                maxx = x + w;
              }
            if (h > maxh)
              {
                h = maxh;
                maxy = y + h;
              }

            // too small to be a building, fill with alley tile
            var tile = TEMP_ACTUAL_BUILDING;
            if (w <= 3 || h <= 3)
              tile = TEMP_WALKWAY;

            // fill with new tile (with walkways around)
            for (yy in y...maxy)
              for (xx in x...maxx)
                cells[xx][yy] =
                  (yy == y || yy == maxy - 1 || xx == x || xx == maxx - 1) ?
                  TEMP_WALKWAY : tile;
          }


#if !js
      for (y in 0...area.height)
        {
          for (x in 0...area.width)
//            Sys.print(cells[x][y] == Const.TILE_BUILDING ? 1 : 0);
            Sys.print(cells[x][y]);
          Sys.println('');
        }
#end
      return;

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

          var t = Const.TILE_BUSH;
          if (Std.random(100) < 30)
            t = Const.TILE_ROCK;
          if (Std.random(100) < 30)
            t = Const.TILE_TREE1 + Std.random(Const.TILE_BUSH - Const.TILE_TREE1);

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
