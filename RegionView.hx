// tiled region view (each tile corresponds to an area)

import com.haxepunk.Entity;
import com.haxepunk.HXP;
import com.haxepunk.graphics.Tilemap;

import game.*;

class RegionView
{
  var game: Game; // game state link
  var scene: GameScene; // scene link

  var _tilemap: Tilemap;
  var _tilemapAlert: Tilemap;
  var _tilemapEvent: Tilemap;
  var _tilemapNPC: Tilemap;
  var _tilemapHabitat: Tilemap;

  public var width: Int; // width, height in cells
  public var height: Int;
  public var entity: Entity; // tilemap entity
  public var entityIcons: Entity; // icons entity

  public function new (s: GameScene)
    {
      scene = s;
      game = scene.game;
      width = 100; // should be larger than any region
      height = 100;

      _tilemap = null;
      _tilemapAlert = null;
      _tilemapEvent = null;
      _tilemapNPC = null;
      _tilemapHabitat = null;

      entity = new Entity();
      entity.layer = Const.LAYER_TILES;
      entityIcons = new Entity();
      entityIcons.layer = Const.LAYER_EFFECT - 1;

      _tilemap = new Tilemap("gfx/tileset.png",
        width * Const.TILE_WIDTH, height * Const.TILE_HEIGHT,
        Const.TILE_WIDTH, Const.TILE_HEIGHT);
      entity.addGraphic(_tilemap);

      // TODO: this needs to be remade through dynamically spawned entities sometime
      // later i guess
      _tilemapAlert = new Tilemap("gfx/entities.png",
        width * Const.TILE_WIDTH, height * Const.TILE_HEIGHT,
        Const.TILE_WIDTH, Const.TILE_HEIGHT);
      entityIcons.addGraphic(_tilemapAlert);

      _tilemapEvent = new Tilemap("gfx/entities.png",
        width * Const.TILE_WIDTH, height * Const.TILE_HEIGHT,
        Const.TILE_WIDTH, Const.TILE_HEIGHT);
      entityIcons.addGraphic(_tilemapEvent);

      _tilemapNPC = new Tilemap("gfx/entities.png",
        width * Const.TILE_WIDTH, height * Const.TILE_HEIGHT,
        Const.TILE_WIDTH, Const.TILE_HEIGHT);
      entityIcons.addGraphic(_tilemapNPC);

      _tilemapHabitat = new Tilemap("gfx/entities.png",
        width * Const.TILE_WIDTH, height * Const.TILE_HEIGHT,
        Const.TILE_WIDTH, Const.TILE_HEIGHT);
      entityIcons.addGraphic(_tilemapHabitat);

      scene.add(entity);
      scene.add(entityIcons);
    }


// update tilemaps from current region
  public function update()
    {
      width = game.region.width;
      height = game.region.height;
/*
      // destroy old tilemap if it exists
      if (_tilemap != null)
        {
          entity.graphic = null;
          entityIcons.graphic = null;
        }
*/

      // set tiles
      var cells = game.region.getCells();
      for (y in 0...height)
        for (x in 0...width)
          _tilemap.setTile(x, y, Const.TILE_REGION_ROW + cells[x][y].tileID); 

      // set all icons
      updateIcons();

      scene.updateCamera(); // center camera on player
    }


// show gui
  public function show()
    {
      // change player entity image and mask
      var row = Const.ROW_PARASITE;
      if (game.player.host != null)
        {
          row = Reflect.field(Const, 'ROW_' + game.player.host.type.toUpperCase());
          game.playerRegion.entity.setMask(Const.FRAME_MASK_REGION, row);
        }
      else game.playerRegion.entity.setMask(Const.FRAME_EMPTY, row);
      game.playerRegion.entity.setImage(Const.FRAME_DEFAULT, row);

      entity.visible = true;
      entityIcons.visible = true;
      game.playerRegion.entity.visible = true;
    }


// hide gui
  public function hide()
    {
      entity.visible = false;
      entityIcons.visible = false;
      game.playerRegion.entity.visible = false;
    }


// update alertness icon for this area
  function updateAlertness(a: AreaGame)
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
  function updateEvent(a: AreaGame)
    {
      if (!game.player.vars.timelineEnabled ||
          a.event == null || !a.event.locationKnown)
        return;

      var frame = Const.FRAME_EVENT_UNKNOWN;
      if (a.event.notesKnown())
        frame = Const.FRAME_EVENT_KNOWN;

      _tilemapEvent.setTile(a.x, a.y, Const.ROW_REGION_ICON * 9 + frame);
    }


// update npc icon for this area
  function updateNPC(a: AreaGame)
    {
      if (!game.player.vars.timelineEnabled || a.npc.length == 0)
        return;

      var ok = true;
      for (npc in a.npc)
        if (!npc.isDead && npc.areaKnown && !npc.memoryKnown)
          ok = false;

      _tilemapNPC.setTile(a.x, a.y,
        Const.ROW_REGION_ICON * 9 + (ok ? Const.FRAME_EMPTY : Const.FRAME_EVENT_NPC));
    }


// update icons on this area
  public function updateIconsArea(x: Int, y: Int)
    {
      var a = game.region.getXY(x, y);

      updateAlertness(a);
      updateEvent(a);
      updateNPC(a);

      // update habitat icons
      if (a.hasHabitat)
        _tilemapHabitat.setTile(a.x, a.y, 
          Const.ROW_REGION_ICON * 9 + Const.FRAME_HABITAT);
    }


// update icons 
  public inline function updateIcons()
    {
      for (y in 0...height)
        for (x in 0...width)
          updateIconsArea(x, y);
    }


// update tile visibility on current player location and known tiles
  public function updateVisibility()
    {
      // maybe it would be more optimal to store currently drawn tile somewhere?
      for (y in 0...height)
        for (x in 0...width)
          {
            var a = game.region.getXY(x, y);

            if ((Math.abs(game.playerRegion.x - x) < 2 &&
                Math.abs(game.playerRegion.y - y) < 2) || a.isKnown)
              _tilemap.setTile(x, y, Const.TILE_REGION_ROW + a.tileID);
            else _tilemap.setTile(x, y, Const.TILE_HIDDEN);
          }
    }
}
