// the sewer tileset's floor and wall shell, laid over a carved grid
//
// shared by the sewer/habitat generator (game.SewerAreaGenerator) and the mountain cave
// (gen.cave.CaveGen): both carve TILE_WALKWAY markers into rock and hand the grid here. the cave keeps
// the sewer ids on purpose, so the tileset, walkability, sight, the minimap and the cult base's forma
// cursor (which refuses wall shell tiles) all read it unchanged. lives under gen/ so the headless
// oracle can run it; game/ calling into gen/ is the allowed direction

package gen;

import tiles.Sewers;

class SewerShell
{
// convert walkway markers into sewer floor and wall shell tiles
  public static function finalize(cells: Array<Array<Int>>, w: Int, h: Int)
    {
      var floorMap: Array<Array<Bool>> = [];
      for (x in 0...w)
        {
          floorMap[x] = [];
          for (y in 0...h)
            floorMap[x][y] = (cells[x][y] == Const.TILE_WALKWAY);
        }

      for (y in 0...h)
        for (x in 0...w)
          {
            if (floorMap[x][y])
              {
                cells[x][y] = Sewers.TILE_FLOOR;
                continue;
              }
            if (isWallShell(floorMap, x, y))
              cells[x][y] = getWallTileID(floorMap, x, y);
            else cells[x][y] = getDiagonalCornerTileID(floorMap, x, y);
          }
    }

// check whether this cell should become a visible wall shell tile
  static inline function isWallShell(floorMap: Array<Array<Bool>>, x: Int, y: Int): Bool
    {
      return (getFloor(floorMap, x, y - 1) ||
        getFloor(floorMap, x, y + 1) ||
        getFloor(floorMap, x - 1, y) ||
        getFloor(floorMap, x + 1, y));
    }

// safely read floor-map occupancy
  static inline function getFloor(floorMap: Array<Array<Bool>>, x: Int, y: Int): Bool
    {
      if (x < 0 ||
          y < 0 ||
          x >= floorMap.length ||
          y >= floorMap[x].length)
        return false;
      return floorMap[x][y];
    }

// map wall shell shape to one sewer wall tile id
  static function getWallTileID(floorMap: Array<Array<Bool>>, x: Int, y: Int): Int
    {
      var n = getFloor(floorMap, x, y - 1);
      var s = getFloor(floorMap, x, y + 1);
      var w = getFloor(floorMap, x - 1, y);
      var e = getFloor(floorMap, x + 1, y);

      if (e &&
          s &&
          !n &&
          !w)
        return Sewers.TILE_WALL_INNER_TOP_LEFT;
      if (w &&
          s &&
          !n &&
          !e)
        return Sewers.TILE_WALL_INNER_TOP_RIGHT;
      if (e &&
          n &&
          !s &&
          !w)
        return Sewers.TILE_WALL_INNER_BOTTOM_LEFT;
      if (w &&
          n &&
          !s &&
          !e)
        return Sewers.TILE_WALL_INNER_BOTTOM_RIGHT;

      if (n &&
          w &&
          !s &&
          !e)
        return Sewers.TILE_WALL_OUTER_TOP_LEFT;
      if (n &&
          e &&
          !s &&
          !w)
        return Sewers.TILE_WALL_OUTER_TOP_RIGHT;
      if (s &&
          w &&
          !n &&
          !e)
        return Sewers.TILE_WALL_OUTER_BOTTOM_LEFT;
      if (s &&
          e &&
          !n &&
          !w)
        return Sewers.TILE_WALL_OUTER_BOTTOM_RIGHT;

      if (s && !n)
        return Sewers.TILE_WALL_UPPER;
      if (n && !s)
        return Sewers.TILE_WALL_LOWER;
      if (e && !w)
        return Sewers.TILE_WALL_LEFT;
      if (w && !e)
        return Sewers.TILE_WALL_RIGHT;

      if (s)
        return Sewers.TILE_WALL_UPPER;
      if (n)
        return Sewers.TILE_WALL_LOWER;
      if (e)
        return Sewers.TILE_WALL_LEFT;
      if (w)
        return Sewers.TILE_WALL_RIGHT;
      return Const.TILE_HIDDEN;
    }

// map single diagonal floor adjacency to an outer-corner wall tile
  static inline function getDiagonalCornerTileID(
      floorMap: Array<Array<Bool>>, x: Int, y: Int): Int
    {
      var n = getFloor(floorMap, x, y - 1);
      var s = getFloor(floorMap, x, y + 1);
      var w = getFloor(floorMap, x - 1, y);
      var e = getFloor(floorMap, x + 1, y);
      if (n || s || w || e)
        return Const.TILE_HIDDEN;

      var nw = getFloor(floorMap, x - 1, y - 1);
      var ne = getFloor(floorMap, x + 1, y - 1);
      var sw = getFloor(floorMap, x - 1, y + 1);
      var se = getFloor(floorMap, x + 1, y + 1);
      var diagonalFloors = 0;
      if (nw)
        diagonalFloors++;
      if (ne)
        diagonalFloors++;
      if (sw)
        diagonalFloors++;
      if (se)
        diagonalFloors++;
      if (diagonalFloors != 1)
        return Const.TILE_HIDDEN;

      if (nw)
        return Sewers.TILE_WALL_OUTER_TOP_LEFT;
      if (ne)
        return Sewers.TILE_WALL_OUTER_TOP_RIGHT;
      if (sw)
        return Sewers.TILE_WALL_OUTER_BOTTOM_LEFT;
      if (se)
        return Sewers.TILE_WALL_OUTER_BOTTOM_RIGHT;
      return Const.TILE_HIDDEN;
    }
}
