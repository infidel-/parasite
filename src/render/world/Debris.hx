package render.world;

import Const;
import _AreaType;
import citygen.CityConfig;
import citygen.CityModel.Tile;

// one placed debris fragment: a cell + sub-cell offset (fractional, -0.5..0.5), draw transform,
// and the atlas cell (ix=col, iy=row) to crop, off `img` (a litter pack's Images.getImage name) or
// off entities64 when it is null. `scale` is a factor on Sprites.SIZE for an entities64 cell and the
// drawn longest side in world units for a pack cell (AreaStyle.debrisSizes). render-only — never
// persisted
typedef DebrisSpot = { col:Int, row:Int, dx:Float, dy:Float, scale:Float, angle:Float, ix:Int, iy:Int, ?img:String };

// seed-deterministic street-debris scatter for the 3D city. rebuilt from the seed on every city
// show (nothing persisted), so it costs no save space and always matches the same seed. ports the
// old CityAreaGenerator debris passes (street-tile gate + tier/highCrime chance + transformable
// clusters / static singles), drawing per-fragment scale/angle/offset like the sewer version.
// burning barrels are NOT here — they change walkability, so they stay real persisted objects
class Debris {

// build the debris list for a city: iterate street tiles, roll per tier, emit fragments. off the
// tier's litter PACK64 (AreaStyle.debrisPack) when it has one, the shared entities64 rows otherwise
  public static function build(seed:Int, tiles:Array<Array<Tile>>, typeID:_AreaType, highCrime:Bool, style:AreaStyle):Array<DebrisSpot>
    {
      var pack = style.debrisPack;
      var rng = citygen.CityGen.mulberry32(seed);
      var spots:Array<DebrisSpot> = [];
      var g = CityConfig.GRID;
      // the ground test, built once and threaded through: it is the ONLY thing the city scatter
      // and the tunnel one (render.sewer.SewerDebris) do not share
      var ok = function(x:Int, y:Int):Bool return isStreet(tileAt(tiles, x, y));
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
              addTransformable(spots, ok, x, y, typeID, rng, pack);
            else
              addFragment(spots, x, y, (pack != null ? Const.DEBRIS_PACK_STATIC : Const.STREET_DEBRIS_STATIC),
                false, rng, ok, pack);
          }
      // a pack cell is drawn at its own size and not at the cluster's random scale: the art draws a
      // matchbox and a flattened box the same size in their cells. a cell sized 0 is never laid
      if (style.debrisSizes == null)
        return spots;
      var out = [];
      for (s in spots)
        {
          var size = style.debrisSizes[s.iy][s.ix];
          if (size <= 0)
            continue;
          s.scale = size * (0.8 + 0.4 * rng());
          out.push(s);
        }
      return out;
    }

// drop a transformable debris cluster: a center pile plus a radial scatter of smaller piles
  static function addTransformable(spots:Array<DebrisSpot>, ok:Int->Int->Bool,
      x:Int, y:Int, typeID:_AreaType, rng:Void->Float, pack:String)
    {
      var centerCount = 3 + Std.int(rng() * 2);
      spawnCluster(spots, ok, x, y, centerCount, rng, pack);

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
            if (!ok(nx, ny))
              continue;

            var neighbourCount = 1 + Std.int(rng() * 4);
            if (typeID != AREA_CITY_LOW)
              neighbourCount += 1 + Std.int(rng() * 2);
            spawnCluster(spots, ok, nx, ny, neighbourCount, rng, pack);
          }
    }

// spawn `amount` transformable fragments on one tile, off a litter pack or the entities64 rows
  public static function spawnCluster(spots:Array<DebrisSpot>, ok:Int->Int->Bool,
      x:Int, y:Int, amount:Int, rng:Void->Float, ?pack:String)
    {
      for (_ in 0...amount)
        addFragment(spots, x, y, (pack != null ? Const.DEBRIS_PACK_TRANSFORMABLE : Const.STREET_DEBRIS_TRANSFORMABLE),
          true, rng, ok, pack);
    }

// add one debris fragment: pick a sprite, a transform, and a validated sub-cell offset.
// `ok(col,row)` is the caller's ground test — a street tile in the city, SewerModel.isFloor
// underground — which is why this is shared rather than reimplemented per area kind
  public static function addFragment(spots:Array<DebrisSpot>, x:Int, y:Int,
      infos:Array<_TileRow>, transformable:Bool, rng:Void->Float, ok:Int->Int->Bool, ?img:String)
    {
      var info = infos[Std.int(rng() * infos.length)];
      var ix = Std.int(rng() * info.amount) +
        (info.col != null ? info.col : 0);
      var iy = info.row;

      var scale = (transformable ? 0.1 + 0.9 * rng() : 1.0);
      var angle = (transformable ? 2 * Math.PI * rng() : 0.0);
      var dx = 0.0;
      var dy = 0.0;
      // try a few random offsets (±0.4 cell) that keep the fragment over eligible ground
      if (transformable)
        for (_ in 0...8)
          {
            var cdx = (rng() - 0.5) * 0.8;
            var cdy = (rng() - 0.5) * 0.8;
            if (!canPlace(ok, x, y, cdx, cdy))
              continue;
            dx = cdx;
            dy = cdy;
            break;
          }

      spots.push({
        col: x,
        row: y,
        dx: dx,
        dy: dy,
        scale: scale,
        angle: angle,
        ix: ix,
        iy: iy,
        img: img,
      });
    }

// an offset that overhangs a neighbour cell is only allowed if that neighbour is eligible too
  static inline function canPlace(ok:Int->Int->Bool, x:Int, y:Int, dx:Float, dy:Float):Bool
    {
      if (dx > 0.25 &&
          !ok(x + 1, y))
        return false;
      if (dx < -0.25 &&
          !ok(x - 1, y))
        return false;
      if (dy > 0.25 &&
          !ok(x, y + 1))
        return false;
      if (dy < -0.25 &&
          !ok(x, y - 1))
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
