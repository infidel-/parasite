// - has all links to windows and handles input

import js.html.CanvasElement;
import js.Browser;

import ui.*;
import game.Game;

class GameScene
{
  public var game: Game; // game state link
  public var area: AreaView; // area view
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

  var _inputState: Int; // action input state (0 - 1..9, 1 - 10..19, etc)


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

#if !electron
      // focus/blur handling
      win.addEventTarget(function (e: hxd.Event) {
        if (e.kind == EFocus)
          {
            // skip first focus on web
            if (isFocused)
              return;

            // show blur on losing focus
            // this is needed for web because it's too easy to press Alt, lose it and not notice it
            loseFocus.hide();
            sounds.resume();
            isFocused = true;
          }
        else if (e.kind == EFocusLost)
          {
            // reset input flags
            controlPressed = false;
            shiftPressed = false;
            mouse.ignoreNextClick = true; // ignore click on screen
            isFocused = false;

            loseFocus.show();
            sounds.pause();
          }
      });
#end
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

      x -= canvas.width / 2;
      y -= canvas.height / 2;
      x = Math.ceil(x / Const.TILE_SIZE) * Const.TILE_SIZE;
      y = Math.ceil(y / Const.TILE_SIZE) * Const.TILE_SIZE;

      // limit camera x,y by map edges
      if (!game.config.alwaysCenterCamera)
        {
          if (x + canvas.width > Const.TILE_SIZE * w)
            x = Const.TILE_SIZE * w - canvas.width;
          if (y + canvas.height > Const.TILE_SIZE * h)
            y = Const.TILE_SIZE * h - canvas.height;
          if (x < 0)
            x = 0;
          if (y < 0)
            y = 0;
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

