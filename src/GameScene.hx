// - has all links to windows and handles input

import js.html.CanvasElement;
import js.Browser;
import haxe.Timer;

import ui.*;
import game.Game;
import citygen.CityModel.Tile;

class GameScene
{
  public var game: Game; // game state link
  public var area: AreaView; // area view
  public var areaLighting: AreaLighting;
  public var region: RegionView; // region view
  public var view3d: render.View; // 3D area view (city streets + the underground tunnels)
  public var mouse: Mouse; // mouse cursor entity
  public var sounds: Sounds;
  public var controlPressed: Bool; // Ctrl key pressed?
  public var controlKey: String; // ctrl / alt
  public var shiftPressed: Bool; // Shift key pressed?
  var isFullScreen: Bool; // game is in fullscreen mode?
  var isFocused: Bool;
  
  // new draw
  public var images: Images;
  public var canvas: CanvasElement;
  public var mouseX: Float;
  public var mouseY: Float;

  // camera x,y
  public var cameraTileX1: Int;
  public var cameraTileY1: Int;
  public var cameraTileX2: Int;
  public var cameraTileY2: Int;
  public var cameraX: Int;
  public var cameraY: Int;
  public var cameraSubX: Int;
  public var cameraSubY: Int;

  var fader: Fader; // full-screen black fade masking area<->region transition stalls
  var _view3dArea: Int = -1; // id of the area currently shown in the 3D view
  var _enter3D: Bool = false; // a 3D-view enter fade+build is in flight (guard re-entry)
  static inline var FADE_MS = 150; // transition fade duration (1x BASE_MS)
  var _inputState: Int; // action input state (0 - 1..9, 1 - 10..19, etc)
  var _renderStatsArea: _RenderStats;
  var _renderStatsRegion: _RenderStats;


  public function new(g: Game)
    {
      isFocused = true; // may not be true but we want the game to play immediately
      isFullScreen = false;
      game = g;
      controlPressed = false;
      shiftPressed = false;
      cameraTileX1 = 0;
      cameraTileY1 = 0;
      cameraTileX2 = 0;
      cameraTileY2 = 0;
      cameraSubX = 0;
      cameraSubY = 0;

      var os = Browser.navigator.platform;
      if (os.indexOf('Linux') >= 0) // use C-1 on Linux
        controlKey = 'ctrl';
      else
        controlKey = 'alt';

      // handle resize
      // needed for hxd
      Browser.window.onresize = function ()
        {
          resize();
        };
      _renderStatsArea = createRenderStats();
      _renderStatsRegion = createRenderStats();
    }


// init scene and game
  public function init()
    {
      // scale tile size
      if (game.config.mapScale != 1)
        Const.TILE_SIZE =
          Std.int(Const.TILE_SIZE_CLEAN * game.config.mapScale);
      canvas = cast Browser.document.getElementById("canvas");

      images = new Images(this);
      mouse = new Mouse(game);
      area = new AreaView(this);
      areaLighting = new AreaLighting(this);
      region = new RegionView(this);
      view3d = new render.View(game);
      fader = new Fader();

      // init sound
      sounds = new Sounds(this);

      // update AI hear, view distance
      // clamp so that 4k players do not have it hard
      // derive visible span from canvas (no area yet: world builds on New Game/Load)
      var xmin = Std.int(canvas.width / Const.TILE_SIZE);
      var ymin = Std.int(canvas.height / Const.TILE_SIZE);
      ai.AI.VIEW_DISTANCE = Std.int((xmin < ymin ? xmin : ymin) / 2.5);
      ai.AI.HEAR_DISTANCE = Std.int((xmin < ymin ? xmin : ymin) * 1.5 / 2.5);
      if (ai.AI.VIEW_DISTANCE > 6)
        ai.AI.VIEW_DISTANCE = 6;
      if (ai.AI.HEAR_DISTANCE > 10)
        ai.AI.HEAR_DISTANCE = 10;
      game.info('AI view: ' + ai.AI.VIEW_DISTANCE +
        ', AI hear: ' + ai.AI.HEAR_DISTANCE);

      // hack: bugs out otherwise
      game.scene.mouse.setCursor(Mouse.CURSOR_MOVE);

      // run game timer
      Browser.window.setInterval(game.update, 20);
    }

// update camera next tick
  public inline function updateCameraNextTick()
    {
      Browser.window.setTimeout(updateCamera, 1);
    }

// update camera position
  public function updateCamera()
    {
//      trace('updateCamera');
      var x = 0.0, y = 0.0, w = 0.0, h = 0.0;
      if (game.location == LOCATION_AREA)
        {
          x = game.playerArea.x * Const.TILE_SIZE;
          y = game.playerArea.y * Const.TILE_SIZE;
          w = game.area.width;
          h = game.area.height;
        }

      else if (game.location == LOCATION_REGION)
        {
          x = game.playerRegion.x * Const.TILE_SIZE;
          y = game.playerRegion.y * Const.TILE_SIZE;
          w = game.region.width;
          h = game.region.height;
        }

      var centeredX = x - canvas.width / 2;
      var centeredY = y - canvas.height / 2;
      centeredX = Math.ceil(centeredX / Const.TILE_SIZE) * Const.TILE_SIZE;
      centeredY = Math.ceil(centeredY / Const.TILE_SIZE) * Const.TILE_SIZE;

      var mapWidth = Const.TILE_SIZE * w;
      var mapHeight = Const.TILE_SIZE * h;

      if (mapWidth <= canvas.width)
        x = Math.ceil((mapWidth - canvas.width) / 2 / Const.TILE_SIZE) *
          Const.TILE_SIZE;
      else
        {
          x = centeredX;
          if (x < 0)
            x = 0;
          else if (x + canvas.width > mapWidth)
            x = mapWidth - canvas.width;
        }

      if (mapHeight <= canvas.height)
        y = Math.ceil((mapHeight - canvas.height) / 2 / Const.TILE_SIZE) *
          Const.TILE_SIZE;
      else
        {
          y = centeredY;
          if (y < 0)
            y = 0;
          else if (y + canvas.height > mapHeight)
            y = mapHeight - canvas.height;
        }

      // update tile x,y
      cameraTileX1 = Std.int(x / Const.TILE_SIZE);
      cameraTileY1 = Std.int(y / Const.TILE_SIZE);
      cameraTileX2 =
        Std.int((x + canvas.width) / Const.TILE_SIZE);
      cameraTileY2 =
        Std.int((y + canvas.height) / Const.TILE_SIZE);
      cameraX = Std.int(x);
      cameraY = Std.int(y);
      cameraSubX = cameraX - cameraTileX1 * Const.TILE_SIZE;
      cameraSubY = cameraY - cameraTileY1 * Const.TILE_SIZE;

      // force update mouse and path
      mouse.update(true);
      // redraw scene
      draw();
    }

// redraw scene
  public function draw()
    {
      // clear canvas
      var ctx = canvas.getContext('2d');
      ctx.fillStyle = '#000000';
      ctx.fillRect(0, 0, canvas.width, canvas.height);
      ctx.textAlign = 'center';

      if (game.location == LOCATION_AREA && is3DArea())
        draw3D();

      else if (game.location == LOCATION_AREA)
        {
          hide3D();
          game.scene.area.draw();
        }

      else if (game.location == LOCATION_REGION)
        {
          // leaving a city area: let the zoom-in outro finish (it covers the region); its
          // completion (on3DExitDone) covers to black, then draws/generates the region under
          // black. don't draw the region now — that would run the heavy first-draw gen stall
          // straight into the outro's frames
          if (view3d.running)
            {
              hide3D();
              return;
            }
          hide3D();
          game.scene.region.draw();
        }
    }

// is the current area rendered in 3D? city streets, the underground tunnels (sewers share their
// generator with the habitat, so both come out as the same Sewers.TILE_FLOOR grid) and the open
// wilderness
  public inline function is3DArea(): Bool
    {
      return game.area != null &&
        (game.area.info.type == 'city' ||
         game.area.info.type == 'sewers' ||
         game.area.info.type == 'habitat' ||
         game.area.info.type == 'wilderness');
    }

// an object that draws as a 3D prop appeared or vanished in the area on screen. object props are
// placed once at area build, so without this a habitat object grown under the player would draw
// nothing at all until the area was left and re-entered (its sprite is dropped the moment it has a
// model). objects drawn as sprites need none of this — the actor layer re-reads them every frame
  public function updateObjects3D()
    {
      if (!is3DArea() ||
          !view3d.running)
        return;
      view3d.refreshObjects();
    }

// is the current area a city (as opposed to the underground tunnels)?
  inline function isCityArea(): Bool
    {
      return game.area != null &&
        game.area.info.type == 'city';
    }

// show/refresh the 3D view for the current area (skips 2D area draw). (re)builds only
// when the shown area changes; seeded areas regenerate from the seed, old seedless
// saves reconstruct plain boxes from the saved tile grid
  function draw3D()
    {
      if (_enter3D)
        return;
      if (game.area.id == _view3dArea && view3d.running)
        return;
      // cover to black, then build the city + arm the zoom-out intro UNDER black (the geometry
      // build + async texture decode is the enter stall), then reveal as the intro plays
      _enter3D = true;
      _view3dArea = game.area.id;
      fader.cover(FADE_MS, function()
        {
          if (game.area.info.type == 'wilderness')
            view3d.showWild(game.area);
          else if (!isCityArea())
            view3d.showSewer(game.area);
          else if (game.area.cityGenSeed >= 0)
            view3d.show(game.area.cityGenSeed);
          else view3d.showCity(reconstructCity());
          _enter3D = false;
          // reveal only once the view has PRESENTED a frame: the first composer.render
          // compiles every scene shader (a multi-second stall on a cold driver cache) and
          // would otherwise run over an already-revealed, never-drawn black canvas.
          // timeout = backstop so black never sticks if the loop dies before a frame
          var revealed = false;
          var reveal = function()
            {
              if (revealed)
                return;
              revealed = true;
              fader.reveal(FADE_MS);
            };
          view3d.onFirstFrame(reveal);
          Browser.window.setTimeout(reveal, 5000);
        });
    }

// hide the 3D view and forget the shown area (so re-entry rebuilds). the outro plays first;
// on3DExitDone then reveals the region
  inline function hide3D()
    {
      _view3dArea = -1;
      view3d.hide(on3DExitDone);
    }

// 3D-view exit outro finished: cover to black, tear the 3D view down and draw the region
// (its first-draw map gen is a heavy synchronous stall) UNDER black, then reveal the region
  function on3DExitDone()
    {
      fader.cover(FADE_MS, function()
        {
          view3d.teardown();
          game.scene.region.draw();
          fader.reveal(FADE_MS);
        });
    }

// rebuild a citygen City from the saved game tile grid (old saves without a seed)
  function reconstructCity(): citygen.CityModel.City
    {
      var cells = game.area.getCells();
      var g = citygen.CityConfig.GRID;
      var tiles = [for (r in 0...g) [for (c in 0...g) gameTileToCity(cells[c][r])]];
      return citygen.CityGen.fromTiles(tiles);
    }

// map a game tile constant to the matching citygen Tile
  inline function gameTileToCity(t: Int): citygen.CityModel.Tile
    {
      if (t == Const.TILE_ROAD ||
          t == Const.TILE_CROSSWALKV ||
          t == Const.TILE_CROSSWALKH)
        return Road;
      if (t == Const.TILE_ALLEY)
        return Alley;
      if (t == Const.TILE_BUILDING)
        return Building;
      return Walkway;
    }

// begin render timing sample
  public inline function beginRenderSample(): Float
    {
      return Timer.stamp() * 1000;
    }

// add area render timing sample
  public inline function endRenderSampleArea(startTS: Float)
    {
      updateRenderStats(_renderStatsArea,
        Timer.stamp() * 1000 - startTS);
    }

// add region render timing sample
  public inline function endRenderSampleRegion(startTS: Float)
    {
      updateRenderStats(_renderStatsRegion,
        Timer.stamp() * 1000 - startTS);
    }

// get formatted area render stats text
  public inline function getAreaRenderStatsText(): String
    {
      return formatRenderStats('Area', _renderStatsArea);
    }

// get formatted area smooth los overlay render stats text
  public inline function getAreaSmoothLOSRenderStatsText(): String
    {
      if (area == null)
        return Const.small('Area smooth LOS overlay render time (ms): N/A<br/>' +
          'Area smooth LOS overlay counts: N/A');
      return area.getSmoothLOSRenderStatsText();
    }

// get plain render profile text for browser console copy-paste
  public function getRenderStatsConsoleText(): String
    {
      return 'Parasite render profile\n' +
        formatRenderStatsConsole('Region', _renderStatsRegion) + '\n' +
        formatRenderStatsConsole('Area', _renderStatsArea) + '\n' +
        getAreaSmoothLOSRenderStatsConsoleText();
    }

// log render profile to browser console
  public inline function logRenderStatsToConsole()
    {
      Browser.console.log(getRenderStatsConsoleText());
    }

// get plain area smooth los overlay profile for browser console copy-paste
  public inline function getAreaSmoothLOSRenderStatsConsoleText(): String
    {
      if (area == null)
        return 'Area smooth LOS overlay: no samples';
      return area.getSmoothLOSRenderStatsConsoleText();
    }

// get formatted region render stats text
  public inline function getRegionRenderStatsText(): String
    {
      return formatRenderStats('Region', _renderStatsRegion);
    }

// create empty render stats holder
  function createRenderStats(): _RenderStats
    {
      return {
        samples: [],
        nextIndex: 0,
        count: 0,
        sumMs: 0,
        maxMs: 0,
        avgMs: 0,
        lastMs: 0,
        fpsHypothetical: 0,
        hasSamples: false,
      };
    }

// update rolling render stats from one sample
  function updateRenderStats(stats: _RenderStats, duration: Float)
    {
      if (duration < 0)
        duration = 0;
      if (stats.count < 10)
        {
          stats.samples.push(duration);
          stats.sumMs += duration;
          stats.count = stats.samples.length;
        }
      else
        {
          var old = stats.samples[stats.nextIndex];
          stats.sumMs -= old;
          stats.samples[stats.nextIndex] = duration;
          stats.sumMs += duration;
          stats.nextIndex++;
          if (stats.nextIndex >= 10)
            stats.nextIndex = 0;
        }
      stats.lastMs = duration;
      stats.avgMs = stats.sumMs / stats.count;
      stats.maxMs = 0;
      for (sample in stats.samples)
        if (sample > stats.maxMs)
          stats.maxMs = sample;
      stats.fpsHypothetical =
        (stats.avgMs > 0 ? 1000 / stats.avgMs : 0);
      stats.hasSamples = true;
    }

// format one render stats block for hud debug output
  function formatRenderStats(label: String, stats: _RenderStats): String
    {
      if (!stats.hasSamples)
        return Const.small(label + ' frame render time (ms): N/A<br/>' +
          label + ' hypothetical FPS: N/A');
      return Const.small(label + ' frame render time (ms): max ' +
        Const.round2(stats.maxMs) + ' / avg ' +
        Const.round2(stats.avgMs) + ' / last ' +
        Const.round2(stats.lastMs) + '<br/>' +
        label + ' hypothetical FPS: ' +
        Const.round2(stats.fpsHypothetical));
    }

// format one render stats block for browser console
  function formatRenderStatsConsole(label: String, stats: _RenderStats): String
    {
      if (!stats.hasSamples)
        return label + ' frame: no samples';
      return label + ' frame ms: max ' + Const.round2(stats.maxMs) +
        ' / avg ' + Const.round2(stats.avgMs) +
        ' / last ' + Const.round2(stats.lastMs) +
        ', hypothetical FPS ' + Const.round2(stats.fpsHypothetical);
    }

// common clear path (both images and list)
  public inline function clearPath()
    {
      if (!game.isInited)
        return;
      area.clearPath(true);
      region.clearPath(true);
    }


// handle window resize event
  public function resize()
    {
      canvas.width = Math.ceil(Browser.window.innerWidth * Browser.window.devicePixelRatio);
      canvas.height = Math.ceil(Browser.window.innerHeight * Browser.window.devicePixelRatio);
      if (view3d != null)
        view3d.resize(Browser.window.innerWidth, Browser.window.innerHeight);
      updateCamera();
      if (game.location == LOCATION_AREA)
        {
          area.update();
          game.area.updateVisibility();
        }
      else if (game.location == LOCATION_REGION)
        region.update();
    }
}

typedef _RenderStats = {
  var samples: Array<Float>;
  var nextIndex: Int;
  var count: Int;
  var sumMs: Float;
  var maxMs: Float;
  var avgMs: Float;
  var lastMs: Float;
  var fpsHypothetical: Float;
  var hasSamples: Bool;
}
