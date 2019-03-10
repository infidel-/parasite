// tiled area view

import com.haxepunk.Entity;
import com.haxepunk.HXP;
import haxepunk.graphics.tile.Tilemap;

import entities.EffectEntity;
import game.Game;

class AreaView
{
  var game: Game; // game state link
  var scene: GameScene; // ui scene

  var _tilemap: Tilemap;
  var _effects: List<EffectEntity>; // visual effects list

  public var width: Int; // area width, height in cells
  public var height: Int;
  public var emptyScreenCells: Int; // amount of empty cells on screen
  var entity: Entity; // area entity
  static var maxSize = 120;

  public function new (s: GameScene)
    {
      scene = s;
      game = scene.game;
      _tilemap = null;
      width = maxSize; // should be larger than any area
      height = maxSize;
      emptyScreenCells = 0;

      entity = new Entity();
      entity.layer = Const.LAYER_TILES;

      _effects = new List<EffectEntity>();

      _tilemap = new Tilemap("gfx/tileset" + Const.TILE_WIDTH + ".png",
        width * Const.TILE_WIDTH, height * Const.TILE_HEIGHT,
        Const.TILE_WIDTH, Const.TILE_HEIGHT);
      entity.addGraphic(_tilemap);
      scene.add(entity);
    }


// update tilemap, etc from current area
  public function update()
    {
      width = game.area.width;
      height = game.area.height;

      // clear tilemap
      for (y in 0...maxSize)
        for (x in 0...maxSize)
          _tilemap.setTile(x, y, Const.TILE_HIDDEN);

      // update tilemap from current area
      var cells = game.area.getCells();
      for (y in 0...height)
        for (x in 0...width)
          _tilemap.setTile(x, y, cells[x][y]);

      scene.updateCamera(); // center camera on player
    }


// show gui
  public function show()
    {
      entity.visible = true;
      if (game.player.state != PLR_STATE_HOST)
        game.playerArea.entity.visible = true;
    }


// hide gui
  public function hide()
    {
      entity.visible = false;
      game.playerArea.entity.visible = false;

      // clear all effects
      for (eff in _effects)
        {
          scene.remove(eff);
          _effects.remove(eff);
        }
    }


// add visual effect entity
  public function addEffect(x: Int, y: Int, turns: Int, frame: Int)
    {
      if (x >= width || y >= height || x < 0 || y < 0)
        return;

      var effect = new EffectEntity(game, x, y, turns, Const.ROW_EFFECT, frame);
      _effects.add(effect);
      scene.add(effect);
    }


// update AI visibility
  public inline function updateVisibility()
    {
      if (game.player.state == PLR_STATE_HOST)
        updateVisibilityHost();
      else updateVisibilityParasite();
    }


// update visible area
// host version
  function updateVisibilityHost()
    {
      // calculate visible rectangle
      var rect = game.area.getVisibleRect();
      var cells = game.area.getCells();

      emptyScreenCells = 0;
      for (y in rect.y1...rect.y2)
        for (x in rect.x1...rect.x2)
          {
            // count number of empty cells on screen
            if (game.area.isWalkable(x, y))
              emptyScreenCells++;

            if (!game.player.vars.losEnabled ||
                game.area.isVisible(game.playerArea.x,
                  game.playerArea.y, x, y))
              _tilemap.setTile(x, y, cells[x][y]);
            else _tilemap.setTile(x, y, Const.TILE_HIDDEN);
          }
    }


// update visible area
// parasite version
// parasite only sees one tile around him but "feels" AIs in a larger radius
  function updateVisibilityParasite()
    {
      // calculate visible rectangle
      var rect = game.area.getVisibleRect();
      var cells = game.area.getCells();

      // set visibility for all tiles in that area
      emptyScreenCells = 0;
      for (y in rect.y1...rect.y2)
        for (x in rect.x1...rect.x2)
          {
            // count number of empty cells on screen
            if (game.area.isWalkable(x, y))
              emptyScreenCells++;

            if (Math.abs(game.playerArea.x - x) < 2 &&
                Math.abs(game.playerArea.y - y) < 2)
              _tilemap.setTile(x, y, cells[x][y]);
            else _tilemap.setTile(x, y, Const.TILE_HIDDEN);
          }
    }


// returns whether this tile is currently visible to the player
// using graphics tile cache
  public inline function isVisible(x: Int, y: Int): Bool
    {
      return (_tilemap.getTile(x, y) != Const.TILE_HIDDEN);
    }


// TURN: area time passage
  public function turn()
    {
      // effect removal
      for (e in _effects)
        {
          e.turns--;
          if (e.turns <= 0)
            {
              scene.remove(e);
              _effects.remove(e);
            }
        }
    }
}
