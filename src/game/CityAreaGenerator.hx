// city area generation
//
// thin adapter over the shared citygen.CityGen procedural generator: run it,
// translate its pure Tile grid into game tiles, keep the crosswalk pass, and seed
// sewer-hatch spawn points. The 3D street renderer rebuilds all geometry from the
// same seed (stored on the area), so only that seed is persisted for it.

package game;

import const.WorldConst;
import Const;
import objects.*;
import game.AreaGame;
import game.AreaGenerator;
import game.AreaGenerator._GeneratorState;
import citygen.CityGen;
import citygen.CityProfile.Profiles;
import citygen.CityModel.Tile;

class CityAreaGenerator
{
  var game: Game;
  var gen: AreaGenerator;
  // carved inner-courtyard rects from the last generate() (enclosed open pockets); barrels go here
  var courtyards: Array<citygen.CityModel.CourtRect> = [];

// store references to the owning game and shared generator helpers
  public function new(g: Game, gn: AreaGenerator)
    {
      game = g;
      gen = gn;
    }

// generate a city block from the shared procedural generator
  public function generate(state: _GeneratorState, area: AreaGame, info: AreaInfo)
    {
      // pick and store the seed so the 3D renderer regenerates identical geometry; both the
      // logic tiles here and the render pick their profile/style from the same area type
      area.cityGenSeed = Std.random(0x7FFFFFFF);
      var city = CityGen.generate(area.cityGenSeed, Profiles.forArea(area.typeID));
      // keep the carved inner courtyards for the object pass (barrel placement)
      courtyards = city.courtyards;

      // translate the pure Tile grid into game tiles
      // (city grid is [row][col]; game cells are [x][y])
      var cells = area.getCells();
      for (y in 0...area.height)
        for (x in 0...area.width)
          cells[x][y] = tileToGame(city.tiles[y][x]);

      // crosswalks (derived from the tile grid, generator-agnostic)
      addCrosswalks(area);

      // collect sewer-hatch spawn candidates: sidewalk cells bordering a road
      for (y in 0...area.height)
        for (x in 0...area.width)
          if (cells[x][y] == Const.TILE_WALKWAY &&
              (x + y) % 3 == 0 &&
              bordersRoad(area, x, y))
            state.sewers.add({ x: x, y: y });
    }

// generate objects on city block (sewer hatches at seeded spawn points)
  public function generateObjects(state: _GeneratorState, area: AreaGame, info: AreaInfo)
    {
      var spawned = new List();
      for (pt in state.sewers)
        if (Std.random(100) < 20)
          {
            // must sit on a road/walkway cell
            var c = area.getCellType(pt.x, pt.y);
            if (c != Const.TILE_ROAD &&
                c != Const.TILE_WALKWAY)
              continue;

            // keep hatches spaced apart
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

      // impassable burning barrels on low-tier streets
      placeBurningBarrels(area);
    }

// place impassable burning barrels inside low-tier carved inner courtyards: enclosed open pockets
// (ringed by buildings), so a barrel here never blocks a through-corridor. one barrel per courtyard
// at most, at an open interior cell. persisted objects (round-trip by class)
  function placeBurningBarrels(area: AreaGame)
    {
      if (area.typeID != AREA_CITY_LOW)
        return;

      for (c in courtyards)
        {
          // not every courtyard gets one
          if (Std.random(100) >= 60)
            continue;

          // prefer the courtyard centre, else scan for the first open interior cell
          var cx = Std.int((c.x0 + c.x1) / 2);
          var cy = Std.int((c.y0 + c.y1) / 2);
          if (tryPlaceBarrel(area, cx, cy))
            continue;

          var placed = false;
          for (y in c.y0...c.y1 + 1)
            {
              for (x in c.x0...c.x1 + 1)
                if (tryPlaceBarrel(area, x, y))
                  {
                    placed = true;
                    break;
                  }
              if (placed)
                break;
            }
        }
    }

// place one burning barrel on an open alley cell if free; also flip the tile unwalkable. returns
// true on success
  function tryPlaceBarrel(area: AreaGame, x: Int, y: Int): Bool
    {
      if (x < 0 ||
          y < 0 ||
          x >= area.width ||
          y >= area.height)
        return false;
      if (area.getCellType(x, y) != Const.TILE_ALLEY ||
          area.hasObjectAt(x, y))
        return false;

      area.addObject(new BurningBarrel(game, area.id, x, y));
      gen.makeTileUnwalkable(area, x, y);
      return true;
    }

// save migration: rebuild the city tile grid to the area's current (full) size from the
// stored seed. older saves shrank the walkable grid below the CityGen size, leaving 3D
// streets visible but unreachable. objects (sewer hatches, etc) are left untouched
  public function rebuildCells(area: AreaGame)
    {
      var city = CityGen.generate(area.cityGenSeed, Profiles.forArea(area.typeID));
      var cells = area.getCells();
      for (x in 0...area.width)
        if (cells[x] == null)
          cells[x] = [];
      for (y in 0...area.height)
        for (x in 0...area.width)
          cells[x][y] = tileToGame(city.tiles[y][x]);
      addCrosswalks(area);
    }

// map a citygen Tile to the matching game tile constant
  inline function tileToGame(t: Tile): Int
    {
      return switch (t)
        {
          case Tile.Road: Const.TILE_ROAD;
          case Tile.Alley: Const.TILE_ALLEY;
          case Tile.Walkway: Const.TILE_WALKWAY;
          case Tile.Building: Const.TILE_BUILDING;
          default: Const.TILE_WALKWAY;
        };
    }

// does the cell have an orthogonally adjacent road tile?
  inline function bordersRoad(area: AreaGame, x: Int, y: Int): Bool
    {
      return area.getCellType(x - 1, y) == Const.TILE_ROAD ||
        area.getCellType(x + 1, y) == Const.TILE_ROAD ||
        area.getCellType(x, y - 1) == Const.TILE_ROAD ||
        area.getCellType(x, y + 1) == Const.TILE_ROAD;
    }

// paint zebra crosswalks at walkway corners flanked by road (2D/minimap detail)
  function addCrosswalks(area: AreaGame)
    {
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
}
