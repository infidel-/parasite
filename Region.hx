// tiled region view (each tile corresponds to an area)

import com.haxepunk.Entity;
import com.haxepunk.HXP;
import com.haxepunk.graphics.Tilemap;

class Region
{
  var game: Game; // game state link

  var _tilemap: Tilemap;
  var _tilemapAlert: Tilemap;
  var _tilemapEvent: Tilemap;
  var _tilemapNPC: Tilemap;
  var _cells: Array<Array<Int>>; // cell types
  var region: WorldRegion; // region info link

  public var currentArea(get, null): RegionArea; // area player is in

  public var width: Int; // width, height in cells
  public var height: Int;
  public var entity: Entity; // entity
  public var entityAlert: Entity; // entity
  public var entityEvent: Entity; // entity
  public var entityNPC: Entity; // entity
  public var manager: RegionManager; // event manager (region mode)
  public var player: PlayerRegion; // game player (region mode)
  public var debug: DebugRegion; // debug actions (region mode)

  public function new (g: Game)
    {
      game = g;
      _tilemap = null;
      _tilemapAlert = null;
      _tilemapEvent = null;
      _tilemapNPC = null;
      width = 0;
      height = 0;
      entity = new Entity();
      entity.layer = Const.LAYER_TILES;
      entityAlert = new Entity();
      entityAlert.layer = Const.LAYER_TILES - 1;
      entityEvent = new Entity();
      entityEvent.layer = Const.LAYER_EFFECT - 2;
      entityNPC = new Entity();
      entityNPC.layer = Const.LAYER_EFFECT - 3;
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
          entityAlert.graphic = null;
//          _tilemap.destroy(); // unneeded?
        }
  
      _tilemap = new Tilemap("gfx/tileset.png",
        width * Const.TILE_WIDTH, height * Const.TILE_HEIGHT,
        Const.TILE_WIDTH, Const.TILE_HEIGHT);
      entity.addGraphic(_tilemap);

      _tilemapAlert = new Tilemap("gfx/entities.png",
        width * Const.TILE_WIDTH, height * Const.TILE_HEIGHT,
        Const.TILE_WIDTH, Const.TILE_HEIGHT);
      entityAlert.addGraphic(_tilemapAlert);

      // TODO: i'll probably have to rework that into separate entities for icons later
      _tilemapEvent = new Tilemap("gfx/entities.png",
        width * Const.TILE_WIDTH, height * Const.TILE_HEIGHT,
        Const.TILE_WIDTH, Const.TILE_HEIGHT);
      entityEvent.addGraphic(_tilemapEvent);

      _tilemapNPC = new Tilemap("gfx/entities.png",
        width * Const.TILE_WIDTH, height * Const.TILE_HEIGHT,
        Const.TILE_WIDTH, Const.TILE_HEIGHT);
      entityNPC.addGraphic(_tilemapNPC);

      populate();
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

      // set all icons
      updateIcons();

      entity.visible = true;
      entityAlert.visible = true;
      entityEvent.visible = true;
      entityNPC.visible = true;
      player.entity.visible = true;
      updateVisibility();
    }


// hide gui
  public function hide()
    {
      entity.visible = false;
      entityAlert.visible = false;
      entityEvent.visible = false;
      entityNPC.visible = false;
      player.entity.visible = false;
    }


// populate region map
  public function populate()
    {
      _cells = new Array<Array<Int>>();
      for (i in 0...width)
        _cells[i] = [];

      // set tiles
      for (y in 0...height)
        for (x in 0...width)
          {
            var a = region.getXY(x, y);
            setType(x, y, a.tileID); 
          }
    }


// turn in region mode
  public function turn()
    {
      // decrease area alertness everywhere
      for (y in 0...height)
        for (x in 0...width)
          {
            var a = region.getXY(x, y);
            if (a.alertness == 0)
              continue;

            a.alertness -= 1;
          }

      updateIcons();
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


// update alertness icon for this area
  function updateAlertness(a: RegionArea)
    {
      // set alertness mask
      var alertFrame = Const.FRAME_EMPTY;
      if (a.alertness > 75)
        alertFrame = Const.FRAME_ALERT3;
      else if (a.alertness > 50)
        alertFrame = Const.FRAME_ALERT2;
      else if (a.alertness > 0)
        alertFrame = Const.FRAME_ALERT1;
      _tilemapAlert.setTile(a.x, a.y, alertFrame);
    }


// update event icon for this area
  function updateEvent(a: RegionArea)
    {
      if (game.timeline.isLocked || a.event == null || !a.event.locationKnown)
        return;

      var frame = Const.FRAME_EVENT_UNKNOWN;
      if (a.event.notesKnown())
        frame = Const.FRAME_EVENT_KNOWN;

      _tilemapEvent.setTile(a.x, a.y, Const.ROW_REGION_ICON * 9 + frame);
    }


// update npc icon for this area
  public function updateNPC(a: RegionArea)
    {
      if (game.timeline.isLocked || a.npc.length == 0)
        return;

      var ok = true;
      for (npc in a.npc)
        if (!npc.isDead && npc.areaKnown && !npc.memoryKnown)
          ok = false;

      _tilemapNPC.setTile(a.x, a.y,
        Const.ROW_REGION_ICON * 9 + (ok ? Const.FRAME_EMPTY : Const.FRAME_EVENT_NPC));
    }


// update icons 
  function updateIcons()
    {
      for (y in 0...height)
        for (x in 0...width)
          {
            var a = region.getXY(x, y);

            updateAlertness(a);
            updateEvent(a);
            updateNPC(a);
          }
    }


// update tile visibility on current player location and known tiles
  public function updateVisibility()
    {
      // maybe it would be more optimal to store currently drawn tile somewhere?
      for (y in 0...height)
        for (x in 0...width)
          {
            var a = region.getXY(x, y);

            if ((Math.abs(player.x - x) < 2 &&
                Math.abs(player.y - y) < 2) || a.isKnown)
              _tilemap.setTile(x, y, Const.TILE_REGION_ROW + _cells[x][y]);
            else _tilemap.setTile(x, y, Const.TILE_HIDDEN);
          }
    }


// =========================== GETTERS AND SETTERS ==================================


// get area player is in
  public function get_currentArea(): RegionArea
    {
      return region.getXY(player.x, player.y);
    }
}
