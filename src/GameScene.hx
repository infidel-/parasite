// - has all links to windows and handles input

import js.html.CanvasElement;
import js.Browser;
import haxe.Timer;

import ui.*;
import game.Game;

class GameScene
{
  public var game: Game; // game state link
  public var area: AreaView; // area view
  public var areaLighting: AreaLighting;
  public var region: RegionView; // region view
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

      // init sound
      sounds = new Sounds(this);

      // partial game init
      game.init(true);

      // update AI hear, view distance
      // clamp so that 4k players do not have it hard
      var xmin = cameraTileX2 - cameraTileX1;
      var ymin = cameraTileY2 - cameraTileY1;
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

      if (game.location == LOCATION_AREA)
        game.scene.area.draw();

      else if (game.location == LOCATION_REGION)
        game.scene.region.draw();
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
      if (game.location == LOCATION_AREA)
        game.scene.area.clearPath(true);

      else if (game.location == LOCATION_REGION)
        game.scene.region.clearPath(true);
    }


// handle window resize event
  public function resize()
    {
      canvas.width = Math.ceil(Browser.window.innerWidth * Browser.window.devicePixelRatio);
      canvas.height = Math.ceil(Browser.window.innerHeight * Browser.window.devicePixelRatio);
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
