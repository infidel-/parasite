// tiled region view (each tile corresponds to an area)

import com.haxepunk.Entity;
import com.haxepunk.HXP;
import com.haxepunk.graphics.Tilemap;

class Region
{
  var game: Game; // game state link

  var _tilemap: Tilemap;
  var _cells: Array<Array<Int>>; // cell types

  public var width: Int; // width, height in cells
  public var height: Int;
  public var entity: Entity; // entity

  public function new (g: Game, tileset: Dynamic, w: Int, h: Int)
    {
      game = g;
      entity = new Entity();
      entity.layer = Const.LAYER_TILES;
      width = w;
      height = h;

      _tilemap = new Tilemap(tileset, 
        w * Const.TILE_WIDTH, h * Const.TILE_HEIGHT,
        Const.TILE_WIDTH, Const.TILE_HEIGHT);
      entity.addGraphic(_tilemap);
    }


// show gui
  public function show()
    {
      entity.visible = true;
    }


// hide gui
  public function hide()
    {
      entity.visible = false;
    }


// generate a new area map
  public function generate()
    {
      _cells = new Array<Array<Int>>();
      for (i in 0...width)
        _cells[i] = [];

      // clear map
      trace(Const.TILE_REGION_CITY);
      for (y in 0...width)
        for (x in 0...height)
          setType(x, y, Const.TILE_REGION_CITY);
    }


// set cell type 
  inline function setType(x: Int, y: Int, index: Int)
    {
      _tilemap.setTile(x, y, index);
      _cells[x][y] = index;
    }
}
