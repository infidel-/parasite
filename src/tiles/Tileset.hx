// base tileset rendering and tile behavior

package tiles;

import Const;
import js.html.CanvasRenderingContext2D;
import js.html.Image;
import mods.AssetPath;

class Tileset
{
  public var image: Image;
  public var voidTile: _Icon;
  public var splatLayerID: Int; // persisted into SPLAT decorations (Tile.decoration.layerID)

// create tileset, with the image the region map draws from when a path is given
  public function new(?path: String)
    {
      if (path != null)
        {
          image = new Image();
          image.src = AssetPath.resolve(path);
        }
      voidTile = {
        row: 0,
        col: 0,
      };
      splatLayerID = -1;
    }

// map tile id to icon coordinates
  public function getIcon(tileID: Int): _Icon
    {
      if (tileID == Const.TILE_HIDDEN)
        return voidTile;
      return {
        row: Std.int(tileID / 16),
        col: tileID % 16,
      };
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

// draw one tile icon at screen position
  public function draw(ctx: CanvasRenderingContext2D, icon: _Icon, x: Int, y: Int)
    {
      ctx.drawImage(image,
        icon.col * Const.TILE_SIZE_CLEAN,
        icon.row * Const.TILE_SIZE_CLEAN,
        Const.TILE_SIZE_CLEAN,
        Const.TILE_SIZE_CLEAN,
        x,
        y,
        Const.TILE_SIZE,
        Const.TILE_SIZE);
    }
}
