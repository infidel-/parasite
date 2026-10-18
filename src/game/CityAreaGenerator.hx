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
  static inline var CARS_LIT = 3; // of which parked under a steady street lamp first, where there is one
  static inline var CAR_SPACING = 12; // minimum cells between two car wrecks
  static var checked = false;
  var game: Game;
  var gen: AreaGenerator;
  // carved inner-courtyard rects from the last generate() (enclosed open pockets); barrels go here
  var courtyards: Array<citygen.CityModel.CourtRect> = [];
  // the street lamps from the last generate(), for the object pass (car wrecks)
  var lamps: Array<citygen.CityModel.Lamp> = [];

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
      area.cityGenVersion = Profiles.VERSION;
      var city = CityGen.generate(area.cityGenSeed, Profiles.forArea(area.typeID));
      // keep the carved inner courtyards for the object pass (barrel placement), and the street lamps
      // (car wrecks under the lit ones)
      courtyards = city.courtyards;
      lamps = city.lamps;

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

      // and downtown's street furniture down the kerb row and the service alleys, clear of the
      // hatches above
      placeFurniture(area);
    }

// deal downtown's street furniture (the style's `block` ground props): the kerb row of its two-cell
// pavement takes the trees and planters, so the row against the buildings stays the clear walk, and
// the service alleys the compactors. each is a tile flip to the unwalkable twin that
// render.world.StreetProps draws the furniture over, taken off its spot's summed chances: a kerb
// whose road runs straight past and is no hatch, lamp or crosswalk's end; an alley cell a dumpster
// could take (one wall, cuts no route) off the alley's mouth. a downtown generated before the
// two-cell pavement (cityGenVersion 0) keeps its walk-through dressing
  function placeFurniture(area: AreaGame)
    {
      if (area.typeID != AREA_CITY_HIGH ||
          area.cityGenVersion < 1)
        return;
      var kerb = 0.0;
      var service = 0.0;
      for (gp in render.world.AreaStyle.forArea(area.typeID).groundProps)
        if (gp.block == true)
          switch (gp.spot)
            {
              case KERB:
                kerb += gp.chance;
              case SERVICE:
                service += gp.chance;
              default:
            }
      var lit = new Map<Int, Bool>();
      for (l in lamps)
        lit.set(l.row * area.width + l.col, true);
      for (y in 0...area.height)
        for (x in 0...area.width)
          if ((kerbRoad(area, x, y) >= 0 &&
              !area.hasObjectAt(x, y) &&
              !lit.exists(y * area.width + x) &&
              Std.random(10000) < kerb * 10000) ||
              (isServiceSpot(area, x, y) &&
              Std.random(10000) < service * 10000))
            gen.makeTileUnwalkable(area, x, y);
    }

// can a compactor stand here: a dumpster's spot kept off the alley's mouth, where its length along
// the wall would stand out over the pavement
  function isServiceSpot(area: AreaGame, x: Int, y: Int): Bool
    {
      if (!isDumpsterSpot(area, x, y))
        return false;
      var w = 0;
      while (area.getCellType(x + Const.dir4x[w], y + Const.dir4y[w]) != Const.TILE_BUILDING)
        w++;
      var ax = Const.dir4y[w] * Const.dir4y[w];
      var ay = Const.dir4x[w] * Const.dir4x[w];
      return !isStreet(area.getCellType(x + ax, y + ay)) &&
        !isStreet(area.getCellType(x - ax, y - ay));
    }

// is this tile the street: pavement, road or a crossing
  static inline function isStreet(c: Int): Bool
    {
      return c == Const.TILE_WALKWAY ||
        c == Const.TILE_ROAD ||
        c == Const.TILE_CROSSWALKV ||
        c == Const.TILE_CROSSWALKH;
    }

// the one Const.dir4x/dir4y direction from a walkway cell that holds road (a crosswalk included, so
// a corner with two stays out), or -1. -1 as well where that road cell is a crosswalk, whose end
// stays clear, or has walkway either side of it along the kerb: the road turns or ends there, and
// render.world.Ground bevels it into a diagonal kerb
  function kerbRoad(area: AreaGame, x: Int, y: Int): Int
    {
      if (area.getCellType(x, y) != Const.TILE_WALKWAY)
        return -1;
      var found = -1;
      for (i in 0...Const.dir4x.length)
        {
          var c = area.getCellType(x + Const.dir4x[i], y + Const.dir4y[i]);
          if (c != Const.TILE_ROAD &&
              c != Const.TILE_CROSSWALKV &&
              c != Const.TILE_CROSSWALKH)
            continue;
          if (found >= 0)
            return -1;
          found = i;
        }
      if (found < 0)
        return -1;
      var fx = x + Const.dir4x[found];
      var fy = y + Const.dir4y[found];
      var ax = Const.dir4y[found] * Const.dir4y[found];
      var ay = Const.dir4x[found] * Const.dir4x[found];
      if (area.getCellType(fx, fy) != Const.TILE_ROAD ||
          area.getCellType(fx + ax, fy + ay) == Const.TILE_WALKWAY ||
          area.getCellType(fx - ax, fy - ay) == Const.TILE_WALKWAY)
        return -1;
      return found;
    }

// park car wrecks along slum kerbs, spaced apart: two road cells each, end to end along the kerb, both
// flipped to their unwalkable twin and nothing else. a wreck is decoration, not an object: the 3D view
// draws one over every such pair (render.world.StreetProps.wrecks), since nothing else in a city
// makes a road cell unwalkable. a pair is only taken where the road runs on past it, so a wreck
// narrows a street and never closes one. the first CARS_LIT are parked under a lamp that will burn
// steady (render.SceneSetup.lampFate, off the same cell hash the 3D view breaks its lamps with), on a
// kerb most of which is dark
  function placeCars(area: AreaGame)
    {
      if (area.typeID != AREA_CITY_LOW)
        return;
      var style = render.world.AreaStyle.forArea(area.typeID);
      var steady = new Map<Int, Bool>();
      for (l in lamps)
        if (render.SceneSetup.lampFate(l.col, l.row, style) == render.SceneSetup.LAMP_STEADY)
          steady.set(l.row * area.width + l.col, true);
      // every pair, and apart those with a steady lamp on the walkway beside either cell
      var spots = [];
      var under = [];
      for (y in 0...area.height)
        for (x in 0...area.width)
          {
            var tail = carTail(area, x, y);
            if (tail < 0)
              continue;
            var k = kerbOf(area, x, y);
            var kx = Const.dir4x[k];
            var ky = Const.dir4y[k];
            var tx = x + Const.dir4x[tail];
            var ty = y + Const.dir4y[tail];
            var pt = {
              x: x,
              y: y,
              tail: tail,
            };
            if (steady.exists((y + ky) * area.width + x + kx) ||
                steady.exists((ty + ky) * area.width + tx + kx))
              under.push(pt);
            else
              spots.push(pt);
          }
      var placed = [];
      var lit = 0;
      while (placed.length < CARS_LOW)
        {
          var from = (lit < CARS_LIT && under.length > 0 ? under : spots);
          if (from.length == 0)
            break;
          var pt = from.splice(Std.random(from.length), 1)[0];
          var near = false;
          for (old in placed)
            if (Const.distanceSquared(pt.x, pt.y, old.x, old.y) <
                CAR_SPACING * CAR_SPACING)
              near = true;
          if (near ||
              area.hasObjectAt(pt.x, pt.y) ||
              area.hasObjectAt(pt.x + Const.dir4x[pt.tail], pt.y + Const.dir4y[pt.tail]))
            continue;
          gen.makeTileUnwalkable(area, pt.x, pt.y);
          gen.makeTileUnwalkable(area, pt.x + Const.dir4x[pt.tail], pt.y + Const.dir4y[pt.tail]);
          placed.push(pt);
          if (from == under)
            lit++;
        }
    }

// can a wreck's first cell stand here: the Const.dir4x/dir4y index of its second cell, or -1. both
// cells empty road along exactly one walkway on the same side, and road again beyond both away from
// the kerb: facing away from the kerb at (fx, fy), its length runs along (fy, -fx)
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
      var city = CityGen.generate(area.cityGenSeed, Profiles.forArea(area.typeID, area.cityGenVersion));
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
