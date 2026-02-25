// base tileset rendering and tile behavior

package tiles;

import Const;
import js.html.CanvasRenderingContext2D;
import js.html.Image;

class Tileset
{
  public var image: Image;
  public var voidTile: _Icon;
  public var wallDecorationLayers: Array<Image>;

// create tileset from image path
  public function new(path: String)
    {
      image = new Image();
      image.src = path;
      voidTile = {
        row: 0,
        col: 0,
      };
      wallDecorationLayers = [];
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

// add one wall decoration image layer
  public function addWallDecorationLayer(path: String)
    {
      var layer = new Image();
      layer.src = path;
      wallDecorationLayers.push(layer);
    }

// get number of wall decoration image layers
  public function getWallDecorationLayerCount(): Int
    {
      return wallDecorationLayers.length;
    }

// check if tile id is a wall tile for decoration painting
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

// draw all wall decoration icons for this tile at screen position
  public function drawWallDecoration(ctx: CanvasRenderingContext2D, icon: _Icon,
      tileID: Int, tile: tiles.Tile, x: Int, y: Int)
    {
      if (tileID == Const.TILE_HIDDEN ||
          !isWallTile(tileID) ||
          tile == null ||
          tile.decoration == null)
        return;
      for (decoration in tile.decoration)
        {
          var layerID = decoration.layerID;
          if (layerID < 0 ||
              layerID >= wallDecorationLayers.length)
            continue;
          var layer = wallDecorationLayers[layerID];
          if (layer == null)
            continue;
          ctx.drawImage(layer,
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
}
