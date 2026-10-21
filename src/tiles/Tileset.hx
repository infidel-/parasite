// base tileset tile behaviour (walkable, see-through, wall), per area kind

package tiles;

import Const;

class Tileset
{
  public var splatLayerID: Int; // persisted into SPLAT decorations (Tile.decoration.layerID)

// create tileset: tile behaviour only, nothing draws from a tileset image any more (the region map's
// facility and base marks are entities128 cells, Const.FRAME_FACILITY_MARK)
  public function new()
    {
      splatLayerID = -1;
    }

// check if tile is walkable
  public function isWalkable(tileID: Int): Bool
    {
      return false;
    }

// check if tile can be seen through
  public function canSeeThrough(tileID: Int): Bool
    {
      return false;
    }

// check if tile id is a wall tile (forma build rules)
  public function isWallTile(tileID: Int): Bool
    {
      return false;
    }
}
