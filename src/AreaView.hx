// tiled area view

import js.html.CanvasRenderingContext2D;
import entities.EffectEntity;
import game.Game;

class AreaView
{
  var game: Game; // game state link
  var scene: GameScene; // ui scene

  var _effects: List<EffectEntity>; // visual effects list
  var _cache: Array<Array<Int>>; // tiles drawn on screen
  var path: Array<aPath.Node>; // currently visible path
  var fakeHosts: Array<_FakeHost>; // background hosts

  public var width: Int; // area width, height in cells
  public var height: Int;
  public var emptyScreenCells: Int; // amount of empty cells on screen
  static var maxSize = 120;

  public function new (s: GameScene)
    {
      scene = s;
      game = scene.game;
      fakeHosts = [];
      width = maxSize; // should be larger than any area
      height = maxSize;
      emptyScreenCells = 0;
      path = null;

      // init tiles cache 
      _cache = [];
      for (i in 0...width)
        _cache[i] = [];
      for (y in 0...height)
        for (x in 0...width)
          _cache[x][y] = 0;

      _effects = new List<EffectEntity>();
    }

// redraw area map
  public function draw()
    {
//      trace('draw area');
      var ctx = scene.canvas.getContext('2d');

      // tiles
      untyped ctx.imageSmoothingEnabled = false;
      drawTiles(ctx);
      // smooth everything else
      untyped ctx.imageSmoothingEnabled = true;

      // objects
      for (o in game.area.getObjects())
        if (!game.player.vars.losEnabled ||
            (game.player.state != PLR_STATE_HOST && 
             o.sensable()) ||
            (game.playerArea.sees(o.x, o.y) &&
            o.entity.isVisible()))
          o.entity.draw(ctx);

      // effects
      for (e in _effects)
        if (e.isVisible())
          e.draw(ctx);

      // ai and player
      if (game.player.state == PLR_STATE_PARASITE)
        game.playerArea.entity.draw(ctx);
      for (ai in @:privateAccess game.area._ai)
        if (!game.player.vars.losEnabled ||
            (game.playerArea.sees(ai.x, ai.y) &&
            ai.entity.isVisible()))
          ai.entity.draw(ctx);

      // path
      if (path != null)
        for (pos in path)
          ctx.drawImage(scene.images.entities,
            Const.FRAME_DOT * Const.TILE_SIZE_CLEAN, 
            Const.ROW_PARASITE * Const.TILE_SIZE_CLEAN,
            Const.TILE_SIZE_CLEAN,
            Const.TILE_SIZE_CLEAN,

            (pos.x - scene.cameraTileX1) * Const.TILE_SIZE,
            (pos.y - scene.cameraTileY1) * Const.TILE_SIZE,
            Const.TILE_SIZE,
            Const.TILE_SIZE);
    }

// draw area tiles
  function drawTiles(ctx: CanvasRenderingContext2D)
    {
      var rect = game.area.getVisibleRect();
      var cells = game.area.getCells();
      var tileID = 0;
      var icon = null;
      for (y in rect.y1...rect.y2)
        for (x in rect.x1...rect.x2)
          {
            tileID = _cache[x][y];
            icon = {
              row: Std.int(tileID / 16),
              col: tileID % 16,
            };
            ctx.drawImage(scene.images.tileset,
              icon.col * Const.TILE_SIZE_CLEAN, 
              icon.row * Const.TILE_SIZE_CLEAN,
              Const.TILE_SIZE_CLEAN,
              Const.TILE_SIZE_CLEAN,
              (x - scene.cameraTileX1) * Const.TILE_SIZE,
              (y - scene.cameraTileY1) * Const.TILE_SIZE,
              Const.TILE_SIZE,
              Const.TILE_SIZE);

            // corp has fake people in the background
            if (game.area.info.id == AREA_CORP)
              paintFakeHost(ctx, icon, x, y);
          }
    }

// corp has fake people in the background
  function paintFakeHost(ctx, icon, x: Int, y: Int)
    {
      // TILE_ROAD_UNWALKABLE
      if (icon.row != 2 || icon.col < 11)
        return;

      // find host
      var host = null;
      for (h in fakeHosts)
        if (h.x == x && h.y == y)
          {
            host = h;
            break;
          }
      if (host == null)
        return;

      var img = 
        (host.isMale ?
         game.scene.images.male :
         game.scene.images.female);
      ctx.globalAlpha = 0.5;
      ctx.drawImage(img,
        host.ix * Const.TILE_SIZE_CLEAN,
        host.iy * Const.TILE_SIZE_CLEAN + 1,
        Const.TILE_SIZE_CLEAN,
        Const.TILE_SIZE_CLEAN - 1,

        (x - scene.cameraTileX1) * Const.TILE_SIZE +
        Const.TILE_SIZE / 4,
        (y - scene.cameraTileY1) * Const.TILE_SIZE +
        Const.TILE_SIZE / 4,
        Const.TILE_SIZE / 2,
        Const.TILE_SIZE / 2);
      ctx.globalAlpha = 1.0;
    }

// update tilemap, etc from current area
  public function update()
    {
      width = game.area.width;
      height = game.area.height;
      scene.updateCamera(); // center camera on player
    }

// clears visible path
  public function clearPath(?clearAll: Bool = false)
    {
      if (path == null)
        return;
      if (clearAll)
        game.playerArea.clearPath();
      path = null;
      scene.draw();
    }


// updates visible path
  public function updatePath(x1: Int, y1: Int, x2: Int, y2: Int)
    {
      path = game.area.getPath(x1, y1, x2, y2);
      if (path == null)
        return;
      path.pop();
      scene.draw();
    }

// hide gui
  public function hide()
    {
      // clear all effects
      for (eff in _effects)
        _effects.remove(eff);
      path = null;
    }


// add visual effect entity
  public function addEffect(x: Int, y: Int, turns: Int, frame: Int)
    {
      if (x >= width || y >= height || x < 0 || y < 0)
        return;

      var effect = new EffectEntity(game, x, y, turns);
      effect.setIcon('entities', frame, Const.ROW_EFFECT);
      _effects.add(effect);
    }


// update AI visibility
  public inline function updateVisibility()
    {
      if (game.player.state == PLR_STATE_HOST)
        updateVisibilityHost();
      else updateVisibilityParasite();
      scene.draw();
    }


// update visible area
// host version
  function updateVisibilityHost()
    {
      // calculate visible rectangle
      var rect = game.area.getVisibleRect();
      var cells = game.area.getCells();

      emptyScreenCells = 0;
      var tileID = 0;
      for (y in rect.y1...rect.y2)
        for (x in rect.x1...rect.x2)
          {
            // count number of empty cells on screen
            if (game.area.isWalkable(x, y))
              emptyScreenCells++;

            if (!game.player.vars.losEnabled ||
                game.area.isVisible(game.playerArea.x,
                  game.playerArea.y, x, y))
              tileID = cells[x][y];
            else tileID = Const.TILE_HIDDEN;
            setTile(x, y, tileID);
          }
      // additional visibility code, makes walls look better
      if (game.player.vars.losEnabled)
        {
          // go left to right and up/down on each cell
          for (x in rect.x1...rect.x2)
            if (isVisible(x, game.playerArea.y))
              {
                // check up
                var y = game.playerArea.y;
                while (true)
                  {
                    y--;
                    if (y < rect.y1)
                      break;
                    if (isVisible(x, y) && game.area.isWalkable(x, y))
                      continue;
                    setTile(x, y, cells[x][y]);
                    break;
                  }
                // check down
                var y = game.playerArea.y;
                while (true)
                  {
                    y++;
                    if (y >= rect.y2)
                      break;
                    if (isVisible(x, y) && game.area.isWalkable(x, y))
                      continue;
                    setTile(x, y, cells[x][y]);
                    break;
                  }
              }

          // go top to bottom and left/right on each cell
          for (y in rect.y1...rect.y2)
            if (isVisible(game.playerArea.x, y))
              {
                // check left
                var x = game.playerArea.x;
                while (true)
                  {
                    x--;
                    if (x < rect.x1)
                      break;
                    if (isVisible(x, y) && game.area.isWalkable(x, y))
                      continue;
                    setTile(x, y, cells[x][y]);
                    break;
                  }
                // check right
                var x = game.playerArea.x;
                while (true)
                  {
                    x++;
                    if (x >= rect.x2)
                      break;
                    if (isVisible(x, y) && game.area.isWalkable(x, y))
                      continue;
                    setTile(x, y, cells[x][y]);
                    break;
                  }
              }
        }
    }

// set tile at x,y
  inline function setTile(x: Int, y: Int, tileID: Int)
    {
      _cache[x][y] = tileID;
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
      var tileID = 0;
      for (y in rect.y1...rect.y2)
        for (x in rect.x1...rect.x2)
          {
            // count number of empty cells on screen
            if (game.area.isWalkable(x, y))
              emptyScreenCells++;

            if (Math.abs(game.playerArea.x - x) < 2 &&
                Math.abs(game.playerArea.y - y) < 2)
              tileID = cells[x][y];
            else tileID = Const.TILE_HIDDEN;

            _cache[x][y] = tileID;
          }
    }


// returns whether this tile is currently visible to the player
// using graphics tile cache
  public inline function isVisible(x: Int, y: Int): Bool
    {
      return (_cache[x][y] != Const.TILE_HIDDEN);
    }


// TURN: area time passage
  public function turn()
    {
      // effect removal
      for (e in _effects)
        {
          e.turns--;
          if (e.turns <= 0)
            _effects.remove(e);
        }

      // fake hosts logic
      if (game.area.info.id == AREA_CORP)
        turnCorp(false);
    }

// area entered
  public function onEnter()
    {
      fakeHosts = [];
      turnCorp(true);
    }

// corp area turn - fake hosts
  function turnCorp(force: Bool)
    {
      if (game.turns % 3 != 0 && !force)
        return;
      var rect = game.area.getVisibleRect();
      var icon = null;
      var tileID = 0;
      // spawn new ones
      for (y in rect.y1...rect.y2)
        for (x in rect.x1...rect.x2)
          {
            tileID = _cache[x][y];
            icon = {
              row: Std.int(tileID / 16),
              col: tileID % 16,
            };
            // TILE_ROAD_UNWALKABLE
            if (icon.row != 2 || icon.col < 11)
              continue;
            if (Std.random(100) < 95)
              continue;
            var h: _FakeHost = {
              x: x,
              y: y,
              isMale: (Std.random(100) < 50),
              ix: Std.random(10),
              iy: 0,
            }
            h.iy = Std.random(h.isMale ? 8 : 6);
            fakeHosts.push(h);
            // limit amount
            if (fakeHosts.length > 10)
              fakeHosts.shift();
          }
    }
}

typedef _FakeHost = {
  var x: Int;
  var y: Int;
  var isMale: Bool;
  var ix: Int;
  var iy: Int;
}
