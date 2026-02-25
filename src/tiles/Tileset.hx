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
  public var wallDecorationLayerWeights: Array<Int>;

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
      wallDecorationLayerWeights = [];
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
  public function addWallDecorationLayer(path: String, weight: Int = 100)
    {
      var layer = new Image();
      layer.src = path;
      wallDecorationLayers.push(layer);
      wallDecorationLayerWeights.push(weight);
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

// get percent chance to place wall decoration on wall tile
  public function getWallDecorationChance(): Int
    {
      return 60;
    }

// place one wall decoration descriptor on tile if random checks pass
  public function decorateWallTile(area: AreaGame, x: Int, y: Int)
    {
      if (wallDecorationLayers.length <= 0)
        return;

      var tileID = area.getCellType(x, y);
      if (!isWallTile(tileID) ||
          Std.random(100) >= getWallDecorationChance())
        return;

      var layerID = pickWallDecorationLayerID();
      if (layerID < 0)
        return;
      area.addTileDecoration(x, y, {
        layerID: layerID,
      });
    }

// pick one wall decoration layer index by configured weights
  function pickWallDecorationLayerID(): Int
    {
      var totalWeight = 0;
      for (layerWeight in wallDecorationLayerWeights)
        if (layerWeight > 0)
          totalWeight += layerWeight;
      if (totalWeight <= 0)
        return -1;

      var roll = Std.random(totalWeight);
      for (i in 0...wallDecorationLayerWeights.length)
        {
          var layerWeight = wallDecorationLayerWeights[i];
          if (layerWeight <= 0)
            continue;
          if (roll < layerWeight)
            return i;
          roll -= layerWeight;
        }
      return -1;
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
