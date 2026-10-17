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
  static inline var DUMPSTERS_LOW = 8; // dumpsters per slums block
  static inline var DUMPSTERS_MEDIUM = 6; // and per ordinary city block
  static inline var DUMPSTER_SPACING = 10; // minimum cells between two dumpsters
  static inline var CARS_LOW = 6; // car wrecks per slums block
  static inline var CAR_SPACING = 12; // minimum cells between two car wrecks
  static var checked = false;
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

      // and the hideable dumpsters in the back alleys of the two lower tiers
      placeDumpsters(area);

      // and the slums' car wrecks, abandoned at the kerb
      placeCars(area);
    }

// park car wrecks along slum kerbs, spaced apart: two road cells each, end to end along the kerb, the
// first holding the object (objects.CarWreck, which the 3D view draws over both) and both flipped to
// their unwalkable twin, as the burning barrels are. a pair is only taken where the road runs on past
// it, so a wreck narrows a street and never closes one
  function placeCars(area: AreaGame)
    {
      if (area.typeID != AREA_CITY_LOW)
        return;
      var spots = [];
      for (y in 0...area.height)
        for (x in 0...area.width)
          {
            var tail = carTail(area, x, y);
            if (tail >= 0)
              spots.push({
                x: x,
                y: y,
                tail: tail,
              });
          }
      var placed = [];
      while (spots.length > 0 &&
          placed.length < CARS_LOW)
        {
          var pt = spots.splice(Std.random(spots.length), 1)[0];
          var near = false;
          for (old in placed)
            if (Const.distanceSquared(pt.x, pt.y, old.x, old.y) <
                CAR_SPACING * CAR_SPACING)
              near = true;
          if (near ||
              area.hasObjectAt(pt.x, pt.y) ||
              area.hasObjectAt(pt.x + Const.dir4x[pt.tail], pt.y + Const.dir4y[pt.tail]))
            continue;
          new CarWreck(game, area.id, pt.x, pt.y);
          gen.makeTileUnwalkable(area, pt.x, pt.y);
          gen.makeTileUnwalkable(area, pt.x + Const.dir4x[pt.tail], pt.y + Const.dir4y[pt.tail]);
          placed.push(pt);
        }
    }

// can a wreck's front cell stand here: the Const.dir4x/dir4y index of its tail cell, or -1. both
// cells empty road along exactly one walkway on the same side, and road again beyond both away from
// the kerb. the tail is the side render.CityArea.objYaw KERB turns the shell toward: facing away from
// the kerb at (fx, fy), its length runs along (fy, -fx)
  function carTail(area: AreaGame, x: Int, y: Int): Int
    {
      var k = kerbOf(area, x, y);
      if (k < 0)
        return -1;
      var fx = -Const.dir4x[k];
      var fy = -Const.dir4y[k];
      var tx = x + fy;
      var ty = y - fx;
      if (kerbOf(area, tx, ty) != k ||
          area.getCellType(x + fx, y + fy) != Const.TILE_ROAD ||
          area.getCellType(tx + fx, ty + fy) != Const.TILE_ROAD)
        return -1;
      for (i in 0...Const.dir4x.length)
        if (Const.dir4x[i] == fy &&
            Const.dir4y[i] == -fx)
          return i;
      return -1;
    }

// the one Const.dir4x/dir4y direction from an empty road cell that holds a walkway, or -1
  function kerbOf(area: AreaGame, x: Int, y: Int): Int
    {
      if (area.getCellType(x, y) != Const.TILE_ROAD ||
          area.hasObjectAt(x, y))
        return -1;
      var found = -1;
      for (i in 0...Const.dir4x.length)
        if (area.getCellType(x + Const.dir4x[i], y + Const.dir4y[i]) == Const.TILE_WALKWAY)
          {
            if (found >= 0)
              return -1;
            found = i;
          }
      return found;
    }

// place dumpsters against back-alley walls on the two lower tiers, spaced apart. persisted objects,
// solid through Dumpster.isWalkable and NOT a tile flip: rebuildCells regenerates the tiles from the
// seed on old saves and would erase one
  function placeDumpsters(area: AreaGame)
    {
      if (!checked)
        {
          checked = true;
          if (!demo())
            js.Browser.console.warn('[dumpster] ring self-check FAILED');
        }
      var amount = switch (area.typeID)
        {
          case AREA_CITY_LOW: DUMPSTERS_LOW;
          case AREA_CITY_MEDIUM: DUMPSTERS_MEDIUM;
          default: 0;
        };
      if (amount == 0)
        return;

      // every candidate cell, then random picks off that list that keep their distance
      var spots = [];
      for (y in 0...area.height)
        for (x in 0...area.width)
          if (isDumpsterSpot(area, x, y))
            spots.push({ x: x, y: y });
      var placed = [];
      while (spots.length > 0 &&
          placed.length < amount)
        {
          var pt = spots.splice(Std.random(spots.length), 1)[0];
          var near = false;
          for (old in placed)
            if (Const.distanceSquared(pt.x, pt.y, old.x, old.y) <
                DUMPSTER_SPACING * DUMPSTER_SPACING)
              near = true;
          if (near)
            continue;
          new Dumpster(game, area.id, pt.x, pt.y);
          placed.push(pt);
        }
    }

// can a dumpster stand here: an empty alley cell with exactly ONE building beside it (a bin stands
// against a wall, and a one-wide gap between two buildings is a passage it would plug), whose open
// neighbours stay one group around it, so the bin cuts no route
  function isDumpsterSpot(area: AreaGame, x: Int, y: Int): Bool
    {
      if (area.getCellType(x, y) != Const.TILE_ALLEY ||
          area.hasObjectAt(x, y))
        return false;
      var walls = 0;
      for (i in 0...Const.dir4x.length)
        if (area.getCellType(x + Const.dir4x[i], y + Const.dir4y[i]) == Const.TILE_BUILDING)
          walls++;
      if (walls != 1)
        return false;
      return ringConnected(function(i: Int) {
        return isOpen(area.getCellType(x + Const.dirx[i], y + Const.diry[i]));
      });
    }

// is this a tile anybody can walk on (barrel cells are flipped to their unwalkable twins)?
  static inline function isOpen(c: Int): Bool
    {
      return c == Const.TILE_ROAD ||
        c == Const.TILE_ALLEY ||
        c == Const.TILE_WALKWAY ||
        c == Const.TILE_CROSSWALKV ||
        c == Const.TILE_CROSSWALKH;
    }

// do the open cells of the eight around a cell (open(i) over Const.dirx/diry) form ONE group, joined
// 8-way the way everything here walks? false means blocking the middle cell splits them
  static function ringConnected(open: Int->Bool): Bool
    {
      var ring = [];
      for (i in 0...Const.dirx.length)
        if (open(i))
          ring.push(i);
      if (ring.length == 0)
        return false;
      var seen = [ ring[0] ];
      var queue = [ ring[0] ];
      while (queue.length > 0)
        {
          var a = queue.pop();
          for (b in ring)
            if (seen.indexOf(b) < 0 &&
                Math.abs(Const.dirx[a] - Const.dirx[b]) <= 1 &&
                Math.abs(Const.diry[a] - Const.diry[b]) <= 1)
              {
                seen.push(b);
                queue.push(b);
              }
        }
      return seen.length == ring.length;
    }

// self-check of ringConnected on three hand-drawn neighbourhoods
  static function demo(): Bool
    {
      // open(i) from a 3x3 picture, row by row, the middle ignored
      function pic(rows: Array<String>): Int->Bool
        {
          return function(i: Int) {
            return rows[Const.diry[i] + 1].charAt(Const.dirx[i] + 1) == '.';
          };
        }
      // a one-wide corridor: blocking it splits the two ends
      var corridor = !ringConnected(pic([ '#.#', '#.#', '#.#' ]));
      // a bin against one wall of a wide alley: the far side goes round
      var wall = ringConnected(pic([ '...', '...', '###' ]));
      // the inside of an L-bend: the two arms still meet at the corner
      var bend = ringConnected(pic([ '##.', '#..', '...' ]));
      return corridor &&
        wall &&
        bend;
    }

// place impassable burning barrels inside low-tier carved inner courtyards: enclosed open pockets
// (ringed by buildings), so a barrel here never blocks a through-corridor. exactly one barrel per
// courtyard, at an open interior cell. persisted objects (round-trip by class). the count varies
// through the profile's courtyardBlockChance alone — an extra per-courtyard roll here used to cut
// the average to 1.5 barrels/city and left 23% of cities with none at all, which silently broke the
// profane cult ordeals that muster around a barrel
  function placeBurningBarrels(area: AreaGame)
    {
      if (area.typeID != AREA_CITY_LOW)
        return;

      for (c in courtyards)
        {
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
