// base tileset rendering and tile behavior

package tiles;

import Const;
import js.html.CanvasRenderingContext2D;
import js.html.Image;

class Tileset
{
  public var image: Image;
  public var voidTile: _Icon;

// create tileset from image path
  public function new(path: String)
    {
      image = new Image();
      image.src = path;
      voidTile = {
        row: 0,
        col: 0,
      };
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
      if (tileID < 0 ||
          tileID >= Const.TILE_WALKABLE.length)
        return false;
      return Const.TILE_WALKABLE[tileID] == 1;
    }

// check if tile can be seen through
  public function canSeeThrough(tileID: Int): Bool
    {
      if (tileID < 0 ||
          tileID >= Const.TILE_SEETHROUGH.length)
        return false;
      return Const.TILE_SEETHROUGH[tileID] == 1;
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
