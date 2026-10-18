// tiled area view

import js.Browser;
import js.html.CanvasElement;
import particles.Particle;
import entities.EffectEntity;
import game.Game;
import tiles.Tileset;

@:expose
class AreaView
{
  var game: Game; // game state link
  var scene: GameScene; // ui scene
  var minimap: CanvasElement; // minimap element
  var minimapAreaID: Int;

  var _particles: List<Particle>;
  var _effects: List<EffectEntity>; // visual effects list
  var _cache: Array<Array<Int>>; // tiles drawn on screen
  var path: Array<aPath.Node>; // currently visible path
  var _tileset: Tileset;
  var tileset(get, null): Tileset;

  public var width: Int; // area width, height in cells
  public var height: Int;
  public var emptyScreenCells: Int; // amount of empty cells on screen
  static var maxSize = 120;
  var drawIntervalID: Int; // if set, draw will be called every 10 ms

  public function new(s: GameScene)
    {
      scene = s;
      game = scene.game;
      width = maxSize; // should be larger than any area
      height = maxSize;
      emptyScreenCells = 0;
      drawIntervalID = 0;
      path = null;
      minimap = null;
      _tileset = null;

      // init tiles cache 
      _cache = [];
      for (i in 0...width)
        _cache[i] = [];
      for (y in 0...height)
        for (x in 0...width)
          _cache[x][y] = 0;

      _effects = new List();
      _particles = new List();
    }

// add particle to list
  public function addParticle(p: Particle)
    {
      _particles.add(p);
      // set interval to call draw every 10 ms 
      if (drawIntervalID == 0)
        drawIntervalID = Browser.window.setInterval(draw, 10);
    }

// 3D areas draw through render.View; this only retires dead particles. it still has to run: the
// 10ms interval addParticle arms is cleared here, and onDeath() is what persists a splat/money
// stain onto the tile
  public function draw()
    {
      reapParticles();
    }

// retire dead particles and stop the 10ms redraw once nothing needs it. the only place onDeath()
// fires (a splat/money stain is persisted from there) and the only place the interval armed by
// addParticle is cleared
  function reapParticles()
    {
      for (p in _particles)
        if (p.isDead())
          {
            p.onDeath();
            _particles.remove(p);
          }
      // stop redrawing
      if (_particles.length == 0)
        {
          Browser.window.clearInterval(drawIntervalID);
          drawIntervalID = 0;
        }
    }

// update tilemap, etc from current area
  public function update()
    {
      width = game.area.width;
      height = game.area.height;
      _tileset = scene.images.getTileset(game.area.getTilesetTypeID());
      scene.updateCamera(); // center camera on player
    }

// clears visible path
  public function clearPath(?clearAll: Bool = false)
    {
      if (clearAll)
        game.playerArea.clearPath();
      if (scene.view3d != null)
        scene.view3d.clearPathPreview();
      if (path == null)
        return;
      path = null;
      scene.draw();
    }


// updates visible path
  public function updatePath(x1: Int, y1: Int, x2: Int, y2: Int)
    {
      path = game.area.getPath(x1, y1, x2, y2);
      if (path == null)
        {
          if (scene.view3d != null)
            scene.view3d.clearPathPreview();
          return;
        }
      // feed the 3D view its wavy ribbon preview: getPath excludes the player's own cell and
      // includes the goal, so prepend the player cell for a full player -> target line (do this
      // before the pop below, which drops the goal for the 2D dotted overlay)
      if (scene.view3d != null)
        {
          var preview = [ new aPath.Node(x1, y1, 0, null) ];
          for (n in path)
            preview.push(n);
          scene.view3d.setPathPreview(preview);
        }
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
  public function addEffect(x: Int, y: Int, turns: Int, frame: Int): EffectEntity
    {
      if (x >= width || y >= height || x < 0 || y < 0)
        return null;

      var effect = new EffectEntity(game, x, y, turns);
      effect.setIcon('entities', frame, Const.ROW_EFFECT);
      _effects.add(effect);
      return effect;
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
                    if (isVisible(x, y) &&
                        game.area.canSeeThrough(x, y))
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
                    if (isVisible(x, y) &&
                        game.area.canSeeThrough(x, y))
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
                    if (isVisible(x, y) &&
                        game.area.canSeeThrough(x, y))
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
                    if (isVisible(x, y) &&
                        game.area.canSeeThrough(x, y))
                      continue;
                    setTile(x, y, cells[x][y]);
                    break;
                  }
              }

          // if player is inside a room, reveal that room and its perimeter
          revealCurrentRoom(rect, cells);
        }
    }

// reveal current room tiles and perimeter using generator room info
  function revealCurrentRoom(rect: { x1: Int, y1: Int, x2: Int, y2: Int },
      cells: Array<Array<Int>>)
    {
      var info = game.area.generatorInfo;
      if (info == null ||
          info.rooms == null ||
          info.rooms.length == 0)
        return;

      var room = info.getRoomAt(game.playerArea.x, game.playerArea.y);
      if (room == null)
        return;

      revealRoomRect(room, rect, cells);
    }

// reveal room interior and one-tile perimeter
  function revealRoomRect(room: _Room,
      rect: { x1: Int, y1: Int, x2: Int, y2: Int },
      cells: Array<Array<Int>>)
    {
      var sx = room.x1 - 1;
      var sy = room.y1 - 1;
      var ex = room.x2 + 1;
      var ey = room.y2 + 1;

      if (sx < rect.x1)
        sx = rect.x1;
      if (sy < rect.y1)
        sy = rect.y1;
      if (ex >= rect.x2)
        ex = rect.x2 - 1;
      if (ey >= rect.y2)
        ey = rect.y2 - 1;
      if (sx > ex ||
          sy > ey)
        return;

      for (y in sy...ey + 1)
        for (x in sx...ex + 1)
          setTile(x, y, cells[x][y]);
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
          // called on first turn this was created
          if (game.turns <= e.createdOn + 1)
            continue;
          e.turns--;
          if (e.turns <= 0)
            _effects.remove(e);
        }
    }

// area entered
  public function onEnter()
    {
      _tileset = scene.images.getTileset(game.area.getTilesetTypeID());
    }

// generate minimap from tiles
  public function generateMinimap()
    {
      var scale = game.config.minimapScale;
      minimap = Browser.document.createCanvasElement();
      minimap.width = Std.int(game.area.width * scale);
      minimap.height = Std.int(game.area.height * scale);
      var ctx = minimap.getContext2d();
      untyped ctx.imageSmoothingEnabled = true;
      var tileID = 0;
      var icon: _Icon = null;
      var cells = game.area.getCells();
      ctx.fillStyle = 'red';
      ctx.fillRect(0, 0, minimap.width, minimap.height);
      for (y in 0...game.area.height)
        for (x in 0...game.area.width)
          {
            tileID = cells[x][y];
            icon = tileset.getIcon(tileID);
            ctx.drawImage(tileset.image,
              icon.col * Const.TILE_SIZE_CLEAN, 
              icon.row * Const.TILE_SIZE_CLEAN,
              Const.TILE_SIZE_CLEAN,
              Const.TILE_SIZE_CLEAN,

              (x) * scale,
              (y) * scale,
              scale,
              scale);
          }
      // border
      ctx.strokeStyle = '#649afb';
      ctx.lineWidth = 1;
      ctx.strokeRect(0, 0, minimap.width, minimap.height);
    }

// get active area tileset with lazy cache
  function get_tileset(): Tileset
    {
      if (_tileset == null &&
          game.area != null)
        _tileset = scene.images.getTileset(game.area.getTilesetTypeID());
      return _tileset;
    }
}
