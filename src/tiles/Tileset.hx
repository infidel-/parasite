// base tileset rendering and tile behavior

package tiles;

import Const;
import game.AreaGame;
import js.html.CanvasRenderingContext2D;
import js.html.Image;

class Tileset
{
  public var image: Image;
  public var voidTile: _Icon;
  public var wallDecorationLayers: Array<Image>;
  public var wallDecorationLayerRepeatEvery: Array<Int>;
  public var wallDecorationLayerChance: Array<Int>;

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
      wallDecorationLayerRepeatEvery = [];
      wallDecorationLayerChance = [];
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

// add one wall decoration image layer with repeat rule
  public function addWallDecorationLayerRepeat(path: String, repeatEvery: Int)
    {
      var layer = new Image();
      layer.src = path;
      wallDecorationLayers.push(layer);
      wallDecorationLayerRepeatEvery.push(repeatEvery);
      wallDecorationLayerChance.push(-1);
    }

// add one wall decoration image layer with chance rule
  public function addWallDecorationLayerChance(path: String, chance: Int)
    {
      var layer = new Image();
      layer.src = path;
      wallDecorationLayers.push(layer);
      wallDecorationLayerRepeatEvery.push(-1);
      wallDecorationLayerChance.push(chance);
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

// check if tile id is a horizontal wall tile
  public function isHorizontalWallTile(tileID: Int): Bool
    {
      return false;
    }

// check if tile id is a vertical wall tile
  public function isVerticalWallTile(tileID: Int): Bool
    {
      return false;
    }

// place one wall decoration descriptor on tile
  public function decorateWallTile(area: AreaGame, x: Int, y: Int)
    {
      if (wallDecorationLayers.length <= 0)
        return;

      var tileID = area.getCellType(x, y);
      if (!isWallTile(tileID))
        return;

      // first check tile layers with repeat rules
      var repeatLayerID = -1;
      for (i in 0...wallDecorationLayers.length)
        {
          var repeatEvery = wallDecorationLayerRepeatEvery[i];
          if (repeatEvery > 0 &&
              ((isHorizontalWallTile(tileID) &&
                x % repeatEvery == 0) ||
               (isVerticalWallTile(tileID) &&
                y % repeatEvery == 0)))
            {
              repeatLayerID = i;
              break;
            }
        }

      // then check tile layers with chance rules
      var chanceLayerID = -1;
      for (i in 0...wallDecorationLayers.length)
        {
          var chance = wallDecorationLayerChance[i];
          if (chance > 0 &&
              Std.random(100) < chance)
            {
              chanceLayerID = i;
              break;
            }
        }

      // add repeat layer first
      var layerID = repeatLayerID;
      area.addTileDecoration(x, y, {
        layerID: layerID,
      });

      // then add chance layer on top of repeat layer
      if (chanceLayerID >= 0)
        layerID = chanceLayerID;
      if (layerID < 0)
        return;
      area.addTileDecoration(x, y, {
        layerID: layerID,
      });
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
