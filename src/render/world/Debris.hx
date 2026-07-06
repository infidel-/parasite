package render.world;

import Const;
import _AreaType;
import citygen.CityConfig;
import citygen.CityModel.Tile;

// one placed debris fragment: a cell + sub-cell offset (fractional, -0.5..0.5), draw transform,
// and the entities64 atlas cell (ix=col, iy=row) to crop. render-only — never persisted
typedef DebrisSpot = { col:Int, row:Int, dx:Float, dy:Float, scale:Float, angle:Float, ix:Int, iy:Int };

// seed-deterministic street-debris scatter for the 3D city. rebuilt from the seed on every city
// show (nothing persisted), so it costs no save space and always matches the same seed. ports the
// old CityAreaGenerator debris passes (street-tile gate + tier/highCrime chance + transformable
// clusters / static singles), drawing per-fragment scale/angle/offset like the sewer version.
// burning barrels are NOT here — they change walkability, so they stay real persisted objects
class Debris {

// build the debris list for a city: iterate street tiles, roll per tier, emit fragments
  public static function build(seed:Int, tiles:Array<Array<Tile>>, typeID:_AreaType, highCrime:Bool):Array<DebrisSpot>
    {
      var rng = citygen.CityGen.mulberry32(seed);
      var spots:Array<DebrisSpot> = [];
      var g = CityConfig.GRID;
      // tiles are [row][col]
      for (y in 0...g)
        for (x in 0...g)
          {
            var tile = tiles[y][x];
            if (!isStreet(tile))
              continue;
            var chance = chanceFor(typeID, highCrime, tile == Tile.Road);
            if (chance <= 0 ||
                Std.int(rng() * 1000) >= chance)
              continue;

            if (rng() < 0.6)
              addTransformable(spots, tiles, x, y, typeID, rng);
            else
              addFragment(spots, tiles, x, y, Const.STREET_DEBRIS_STATIC, false, rng);
          }
      return spots;
    }

// drop a transformable debris cluster: a center pile plus a radial scatter of smaller piles
  static function addTransformable(spots:Array<DebrisSpot>, tiles:Array<Array<Tile>>,
      x:Int, y:Int, typeID:_AreaType, rng:Void->Float)
    {
      var centerCount = 3 + Std.int(rng() * 2);
      spawnCluster(spots, tiles, x, y, centerCount, rng);

      var radius = 1 + Std.int(rng() * 2);
      for (dx in -radius...radius + 1)
        for (dy in -radius...radius + 1)
          {
            if (dx == 0 &&
                dy == 0)
              continue;
            if ((dx * dx + dy * dy) > radius * radius)
              continue;
            if (rng() >= 0.4)
              continue;

            var nx = x + dx;
            var ny = y + dy;
            if (!isStreet(tileAt(tiles, nx, ny)))
              continue;

            var neighbourCount = 1 + Std.int(rng() * 4);
            if (typeID != AREA_CITY_LOW)
              neighbourCount += 1 + Std.int(rng() * 2);
            spawnCluster(spots, tiles, nx, ny, neighbourCount, rng);
          }
    }

// spawn `amount` transformable fragments on one tile
  static function spawnCluster(spots:Array<DebrisSpot>, tiles:Array<Array<Tile>>,
      x:Int, y:Int, amount:Int, rng:Void->Float)
    {
      for (_ in 0...amount)
        addFragment(spots, tiles, x, y, Const.STREET_DEBRIS_TRANSFORMABLE, true, rng);
    }

// add one debris fragment: pick a sprite, a transform, and a validated sub-cell offset
  static function addFragment(spots:Array<DebrisSpot>, tiles:Array<Array<Tile>>,
      x:Int, y:Int, infos:Array<_TileRow>, transformable:Bool, rng:Void->Float)
    {
      var info = infos[Std.int(rng() * infos.length)];
      var ix = Std.int(rng() * info.amount) +
        (info.col != null ? info.col : 0);
      var iy = info.row;

      var scale = (transformable ? 0.1 + 0.9 * rng() : 1.0);
      var angle = (transformable ? 2 * Math.PI * rng() : 0.0);
      var dx = 0.0;
      var dy = 0.0;
      // try a few random offsets (±0.4 cell) that keep the fragment over street tiles
      if (transformable)
        for (_ in 0...8)
          {
            var cdx = (rng() - 0.5) * 0.8;
            var cdy = (rng() - 0.5) * 0.8;
            if (!canPlace(tiles, x, y, cdx, cdy))
              continue;
            dx = cdx;
            dy = cdy;
            break;
          }

      spots.push({ col: x, row: y, dx: dx, dy: dy, scale: scale, angle: angle, ix: ix, iy: iy });
    }

// an offset that overhangs a neighbour cell is only allowed if that neighbour is a street tile
  static inline function canPlace(tiles:Array<Array<Tile>>, x:Int, y:Int, dx:Float, dy:Float):Bool
    {
      if (dx > 0.25 &&
          !isStreet(tileAt(tiles, x + 1, y)))
        return false;
      if (dx < -0.25 &&
          !isStreet(tileAt(tiles, x - 1, y)))
        return false;
      if (dy > 0.25 &&
          !isStreet(tileAt(tiles, x, y + 1)))
        return false;
      if (dy < -0.25 &&
          !isStreet(tileAt(tiles, x, y - 1)))
        return false;
      return true;
    }

// debris spawn chance out of 1000 by area tier / crime (ported from the old debrisChanceFor)
  static inline function chanceFor(typeID:_AreaType, highCrime:Bool, isRoad:Bool):Int
    {
      return switch (typeID)
        {
          case AREA_CITY_LOW:
            highCrime ? (isRoad ? 30 : 50) : (isRoad ? 10 : 20);
          case AREA_CITY_MEDIUM:
            isRoad ? 10 : 20;
          case AREA_CITY_HIGH:
            isRoad ? 2 : 5;
          default:
            isRoad ? 10 : 20;
        };
    }

// street tile = road / alley / walkway (debris never sits on a building)
  static inline function isStreet(tile:Tile):Bool
    {
      return tile == Tile.Road ||
        tile == Tile.Alley ||
        tile == Tile.Walkway;
    }

// safe tile read (out of bounds -> Building, so it fails the street test)
  static inline function tileAt(tiles:Array<Array<Tile>>, x:Int, y:Int):Tile
    {
      if (x < 0 ||
          y < 0 ||
          x >= CityConfig.GRID ||
          y >= CityConfig.GRID)
        return Tile.Building;
      return tiles[y][x];
    }
}
