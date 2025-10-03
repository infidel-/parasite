// city area generation

package game;

import const.WorldConst;
import objects.*;
import game.AreaGame;
import game.AreaGenerator;
import game.AreaGenerator.*;
import game.AreaGenerator._GeneratorState;

class CityAreaGenerator
{
  var game: Game;
  var gen: AreaGenerator;

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
}
