// tiled area view

import h2d.TileGroup;
import entities.EffectEntity;
import game.Game;

class AreaView
{
  var game: Game; // game state link
  var scene: GameScene; // ui scene

  var _tilemap: TileGroup;
  var _effects: List<EffectEntity>; // visual effects list

  public var width: Int; // area width, height in cells
  public var height: Int;
  public var emptyScreenCells: Int; // amount of empty cells on screen
  static var maxSize = 120;

  public function new (s: GameScene)
    {
      scene = s;
      game = scene.game;
      width = maxSize; // should be larger than any area
      height = maxSize;
      emptyScreenCells = 0;

      trace('area');

      _effects = new List<EffectEntity>();
      _tilemap = new TileGroup(scene.tileAtlas
          [Const.TILE_REGION_GROUND][Const.TILE_BUILDING]);
      scene.add(_tilemap, Const.LAYER_TILES);
      _tilemap.blendMode = None;
    }


// update tilemap, etc from current area
  public function update()
    {
      width = game.area.width;
      height = game.area.height;

      trace('AreaView.update ' + maxSize + ' w:' + width + ', h:' + height);
      _tilemap.clear();
/*
      // clear tilemap
      for (y in 0...maxSize)
        for (x in 0...maxSize)
          _tilemap.add(x * Const.TILE_WIDTH, y * Const.TILE_HEIGHT,
            scene.tileAtlas[Const.TILE_REGION_GROUND]
              [Const.TILE_HIDDEN]);
*/

      // update tilemap from current area
      var cells = game.area.getCells();
      for (y in 0...height)
        for (x in 0...width)
          _tilemap.add(x * Const.TILE_WIDTH, y * Const.TILE_HEIGHT,
            scene.tileAtlas[cells[x][y]][Const.TILE_REGION_GROUND]);

      scene.updateCamera(); // center camera on player
    }


// update camera
  public function updateCamera(x: Int, y: Int)
    {
      _tilemap.x = - x;
      _tilemap.y = - y;

      // adjust all entity positions
      for (ai in game.area.getAllAI())
        ai.entity.setPosition(ai.x, ai.y);
      for (obj in game.area.getObjects())
        obj.entity.setPosition(obj.x, obj.y);
      for (e in _effects)
        e.setPosition(e.x, e.y);
    }


// show gui
  public function show()
    {
      _tilemap.visible = true;
      if (game.player.state != PLR_STATE_HOST)
        game.playerArea.entity.visible = true;
    }


// hide gui
  public function hide()
    {
      _tilemap.visible = false;
      game.playerArea.entity.visible = false;

      // clear all effects
      for (eff in _effects)
        {
          eff.remove();
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
      trace('updateVisibilityHost');
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

/*
            if (!game.player.vars.losEnabled ||
                game.area.isVisible(game.playerArea.x,
                  game.playerArea.y, x, y))
              _tilemap.setTile(x, y, cells[x][y]);
            else _tilemap.setTile(x, y, Const.TILE_HIDDEN);
*/
          }
    }


// update visible area
// parasite version
// parasite only sees one tile around him but "feels" AIs in a larger radius
  function updateVisibilityParasite()
    {
      trace('updateVisibilityParasite');
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

/*
            if (Math.abs(game.playerArea.x - x) < 2 &&
                Math.abs(game.playerArea.y - y) < 2)
              _tilemap.setTile(x, y, cells[x][y]);
            else _tilemap.setTile(x, y, Const.TILE_HIDDEN);
*/
          }
    }


// returns whether this tile is currently visible to the player
// using graphics tile cache
  public inline function isVisible(x: Int, y: Int): Bool
    {
      trace('isVisible');
//      return (_tilemap.getTile(x, y) != Const.TILE_HIDDEN);
      return false;
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
              e.remove();
              _effects.remove(e);
            }
        }
    }
}
