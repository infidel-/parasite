// tiled region view (each tile corresponds to an area)

import com.haxepunk.Entity;
import com.haxepunk.HXP;
import com.haxepunk.graphics.Tilemap;

class Region
{
  var game: Game; // game state link

  var _tileset: Dynamic;
  var _tilemap: Tilemap;
  var _cells: Array<Array<Int>>; // cell types
  var region: WorldRegion; // region info link

  public var width: Int; // width, height in cells
  public var height: Int;
  public var entity: Entity; // entity
  public var manager: RegionManager; // event manager (region mode)
  public var player: PlayerRegion; // game player (region mode)
  public var debug: DebugRegion; // debug actions (region mode)

  public function new (g: Game, tileset: Dynamic)
    {
      game = g;
      _tilemap = null;
      _tileset = tileset;
      width = 0;
      height = 0;
      entity = new Entity();
      entity.layer = Const.LAYER_TILES;
      manager = new RegionManager(g);
      player = new PlayerRegion(g, this);
      debug = new DebugRegion(g, this);
    }


// set current region
  public function setRegion(r: WorldRegion)
    {
      region = r;
      width = region.width;
      height = region.height;

      // destroy old tilemap if it exists
      if (_tilemap != null)
        {
          entity.graphic = null;
//          _tilemap.destroy(); // unneeded?
        }
  
      _tilemap = new Tilemap(_tileset, 
        width * Const.TILE_WIDTH, height * Const.TILE_HEIGHT,
        Const.TILE_WIDTH, Const.TILE_HEIGHT);
      entity.addGraphic(_tilemap);

      generate();
    }


// get region info
  public inline function getRegion(): WorldRegion
    {
      return region;
    }


// show gui
  public function show()
    {
      // change player entity image and mask
      var row = Const.ROW_PARASITE;
      if (game.player.host != null)
        {
          row = Reflect.field(Const, 'ROW_' + game.player.host.type.toUpperCase());
          player.entity.setMask(Const.FRAME_MASK_REGION, row);
        }
      else player.entity.setMask(Const.FRAME_EMPTY, row);
      player.entity.setImage(Const.FRAME_DEFAULT, row);

      entity.visible = true;
      player.entity.visible = true;
    }


// hide gui
  public function hide()
    {
      entity.visible = false;
      player.entity.visible = false;
    }


// generate a new area map
  public function generate()
    {
      _cells = new Array<Array<Int>>();
      for (i in 0...width)
        _cells[i] = [];

      // clear map
      for (y in 0...height)
        for (x in 0...width)
          setType(x, y, Const.TILE_REGION_CITY);
    }


// turn in region mode
  public function turn()
    {
    }


// set cell type 
  inline function setType(x: Int, y: Int, index: Int)
    {
      _tilemap.setTile(x, y, Const.TILE_REGION_ROW + index);
      _cells[x][y] = index;
    }


// check if tile is walkable
  public function isWalkable(x: Int, y: Int): Bool
    {
      if (x < 0 || y < 0 || x >= width || y >= height)
        return false;
    
//      trace(x + ' ' + y + ' ' + _isWalkable[x][y]);
      return Const.TILE_WALKABLE_REGION[_cells[x][y]];
    }
}
