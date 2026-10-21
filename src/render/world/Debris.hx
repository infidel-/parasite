package render.world;

import Const;
import _AreaType;
import citygen.CityConfig;
import citygen.CityModel.Tile;

// one placed debris fragment: a cell + sub-cell offset (fractional, -0.5..0.5), draw transform,
// and the cell (ix=col, iy=row) to crop off `img`, a litter PACK64's Images.getImage name. `scale` is
// the drawn longest side in world units (AreaStyle.debrisSizes, GENERIC_SIZES). render-only — never
// persisted
typedef DebrisSpot = { col:Int, row:Int, dx:Float, dy:Float, scale:Float, angle:Float, ix:Int, iy:Int, img:String };

// seed-deterministic street-debris scatter for the 3D city. rebuilt from the seed on every city
// show (nothing persisted), so it costs no save space and always matches the same seed. ports the
// old CityAreaGenerator debris passes (street-tile gate + tier/highCrime chance + transformable
// clusters / static singles), drawing per-fragment scale/angle/offset like the sewer version.
// burning barrels are NOT here — they change walkability, so they stay real persisted objects
class Debris {
  // the litter PACK64 every NON-city kind lays (render.facility.FacilityDebris, render.sewer
  // .SewerDebris, render.wild.WildDebris): the city tiers each have their own (AreaStyle.debrisPack)
  public static inline var GENERIC_PACK = 'debris-generic';
  // each of its cells' drawn longest side in world units, a pack row per line, the city tiers'
  // AreaStyle.debrisSizes for this one. dumped rubbish runs bigger than the streets' pocket litter:
  // the bin bags and the shirts are what the old entities64 rows mostly were, and at the first pass
  // (a bin bag 0.8) every piece drew about half the size those rows had (0.5-2.1 units), so x1.5
  public static var GENERIC_SIZES = [
    [0.75, 0.75, 0.38, 0.45, 0.45, 0.38, 0.6, 0.38],  // plastic bag, tote, tissue, wrapper, crisp packet, snack bag, knotted bag, napkin
    [0.45, 0.38, 0.38, 0.38, 0.9, 1.2, 1.05, 1.05],   // crumpled paper, paper ball, foil, green paper, small sack, bin bag, beige sack, sweatshirt
    [1.2, 1.2, 0.9, 0.9, 0.3, 0.3, 0.68, 0.6],        // beige bin bag, grey bin bag, two t-shirts, plastic cup, paper cup, paper scraps, plastic shards
    [0.68, 0.52, 0.52, 0.22, 0.52, 0.45, 0.68, 0.52], // pages, flyer, magazine page, cigarette packet, bottles, pizza slice, half pizza, sneaker
    [0.52, 0.52, 0.83, 0.83, 0.75, 0.68, 0.75, 0.68], // two sneakers, shopping bag, carrier bag, newspaper, spilled rice, paper shopping bag, paper bag
    [0.52, 0.52, 0.52, 0.45, 0.27, 0.68, 0.9, 1.2],   // three paper sheets, crushed bottle, crushed can, small box, open box, flattened box
    [1.8, 1.35, 1.5, 1.8, 1.35, 1.5, 1.35, 1.5],      // rubbish pile, gravel, plaster rubble, box pile, box stack, broken crate, dust heap, cardboard
    [1.8, 1.95, 1.35, 1.5, 1.65, 1.5, 1.35, 1.8],     // paper heap, bag pile, collapsed box, small boxes, concrete chunks, bricks, rags, tarp
  ];

// build the debris list for a city: iterate street tiles, roll per tier, emit fragments off the
// tier's litter PACK64 (AreaStyle.debrisPack)
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
              addFragment(spots, x, y, Const.DEBRIS_PACK_STATIC, false, rng, ok, pack);
          }
      return sized(spots, style.debrisSizes, rng);
    }

// the generic pack's size pass, for a non-city scatter laid off GENERIC_PACK. its own fixed-seed rng:
// those builders roll per cell, and the spot order is already deterministic
  public static function generic(spots:Array<DebrisSpot>):Array<DebrisSpot>
    {
      return sized(spots, GENERIC_SIZES, citygen.CityGen.mulberry32(spots.length));
    }

// a pack cell is drawn at its own size and not at the cluster's random scale: the art draws a
// matchbox and a flattened box the same size in their cells. +-20% per spot; a cell sized 0 is
// never laid
  static function sized(spots:Array<DebrisSpot>, sizes:Array<Array<Float>>, rng:Void->Float):Array<DebrisSpot>
    {
      var out = [];
      for (s in spots)
        {
          var size = sizes[s.iy][s.ix];
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

// spawn `amount` transformable fragments on one tile, off a litter pack
  public static function spawnCluster(spots:Array<DebrisSpot>, ok:Int->Int->Bool,
      x:Int, y:Int, amount:Int, rng:Void->Float, pack:String)
    {
      for (_ in 0...amount)
        addFragment(spots, x, y, Const.DEBRIS_PACK_TRANSFORMABLE, true, rng, ok, pack);
    }

// add one debris fragment: pick a sprite, a transform, and a validated sub-cell offset.
// `ok(col,row)` is the caller's ground test — a street tile in the city, SewerModel.isFloor
// underground — which is why this is shared rather than reimplemented per area kind
  public static function addFragment(spots:Array<DebrisSpot>, x:Int, y:Int,
      infos:Array<_TileRow>, transformable:Bool, rng:Void->Float, ok:Int->Int->Bool, img:String)
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
