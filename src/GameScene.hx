// - has all links to windows and handles input

import h2d.Font;
import h2d.Interactive;
import h2d.Object;
import h2d.Scene;
import h2d.Tile;
import hxd.Key;
import hxd.System;
import hxd.Window;
#if js
import js.Browser;
#else
import sys.io.File;
#end

import ui.*;
import game.Game;

class GameScene extends Scene
{
  public var game: Game; // game state link
  public var area: AreaView; // area view
  public var region: RegionView; // region view
  public var blinkingText: BlinkingText; // blinking text
  var tilemapInt: Interactive; // tilemap interactive
  public var mouse: Mouse; // mouse cursor entity
  public var win: Window;
  public var font: Font;
  public var font40: Font;
  public var sounds: Sounds;
  public var atlas: Atlas; // AI tiles atlas
  public var entityAtlas: Array<Array<Tile>>; // entity graphics
  public var tileAtlas: Array<Tile>; // tile graphics
  public var controlPressed: Bool; // Ctrl key pressed?
  public var controlKey: String; // ctrl / alt
  public var shiftPressed: Bool; // Shift key pressed?
  var isFullScreen: Bool; // game is in fullscreen mode?
  var isFocused: Bool;

  // camera x,y
  public var cameraTileX1: Int;
  public var cameraTileY1: Int;
  public var cameraTileX2: Int;
  public var cameraTileY2: Int;
  public var cameraX: Int;
  public var cameraY: Int;

  var _inputState: Int; // action input state (0 - 1..9, 1 - 10..19, etc)
  var _containerBlink: Object;


  public function new(g: Game)
    {
      super();
      _containerBlink = new Object();
      isFocused = true; // may not be true but we want the game to play immediately
      win = Window.getInstance();
      isFullScreen = false;
      game = g;
      controlPressed = false;
      shiftPressed = false;
      cameraTileX1 = 0;
      cameraTileY1 = 0;
      cameraTileX2 = 0;
      cameraTileY2 = 0;

      // set correct window size and center
#if !js
      width = game.config.windowWidth;
      height = game.config.windowHeight;
      if (width < 800)
        width = 800;
      if (height < 600)
        height = 600;
      win.resize(width, height);
      var x = Std.int((System.width - width) / 2);
      var y = Std.int((System.height - height) / 2);
      if (x < 0)
        x = 0;
      if (y < 0)
        y = 0;
      @:privateAccess win.window.setPosition(x, y);
#end

#if js
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
#end
    }


// init scene and game
  public function init()
    {
      // scale tile size
      if (game.config.mapScale != 1)
        Const.TILE_SIZE =
          Std.int(Const.TILE_SIZE_CLEAN * game.config.mapScale);

      // allow repeating keypresses
      Key.ALLOW_KEY_REPEAT = true;

      // load all entity images into atlas
      atlas = new Atlas(this);
      var res = hxd.Res.load('graphics/entities' + Const.TILE_SIZE_CLEAN +
        '.png').toTile();
      entityAtlas = res.grid(Const.TILE_SIZE_CLEAN);
      var res = hxd.Res.load('graphics/tileset' + Const.TILE_SIZE_CLEAN +
        '.png').toTile();
      tileAtlas = res.gridFlatten(Const.TILE_SIZE_CLEAN);
      font = hxd.Res.load('font/OrkneyRegular24.fnt').to(hxd.res.BitmapFont).toFont();
      font40 = hxd.Res.font.OrkneyRegular40.toFont();

      // scale atlases if needed
      if (game.config.mapScale != 1)
        {
          for (tile in tileAtlas)
            tile.scaleToSize(Const.TILE_SIZE, Const.TILE_SIZE);
          for (i in 0...entityAtlas.length)
            for (j in 0...entityAtlas[i].length)
              entityAtlas[i][j].scaleToSize(Const.TILE_SIZE,
                Const.TILE_SIZE);
        }

      mouse = new Mouse(game);
      area = new AreaView(this);
      region = new RegionView(this);

      // team member notification
      blinkingText = new BlinkingText(game, _containerBlink);
      add(_containerBlink, Const.LAYER_HUD);

      // add screen-sized tilemap interactive object
      tilemapInt = new h2d.Interactive(win.width, win.height);
      this.add(tilemapInt, Const.LAYER_TILEMAP);
      tilemapInt.onClick = function (e: hxd.Event)
        { mouse.onClick(e.button); }

      // init sound
      sounds = new Sounds(this);

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

      x -= win.width / 2;
      y -= win.height / 2;
      x = Math.ceil(x / Const.TILE_SIZE) * Const.TILE_SIZE;
      y = Math.ceil(y / Const.TILE_SIZE) * Const.TILE_SIZE;

      // limit camera x,y by map edges
      if (!game.config.alwaysCenterCamera)
        {
          if (x + win.width > Const.TILE_SIZE * w)
            x = Const.TILE_SIZE * w - win.width;
          if (y + win.height > Const.TILE_SIZE * h)
            y = Const.TILE_SIZE * h - win.height;
          if (x < 0)
            x = 0;
          if (y < 0)
            y = 0;
        }

      // update tile x,y
      cameraTileX1 = Std.int(x / Const.TILE_SIZE);
      cameraTileY1 = Std.int(y / Const.TILE_SIZE);
      cameraTileX2 =
        Std.int((x + win.width) / Const.TILE_SIZE);
      cameraTileY2 =
        Std.int((y + win.height) / Const.TILE_SIZE);
      cameraX = Std.int(x);
      cameraY = Std.int(y);

      // adjust tilemap and player entity position
      if (game.location == LOCATION_AREA)
        {
          game.playerArea.entity.setPosition(
            game.playerArea.x, game.playerArea.y);
          area.updateCamera(cameraX, cameraY);
        }
      else if (game.location == LOCATION_REGION)
        {
          game.playerRegion.entity.setPosition(
            game.playerRegion.x, game.playerRegion.y);
          region.updateCamera(cameraX, cameraY);
        }

      // force update mouse and path
      mouse.update(true);
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
      tilemapInt.width = win.width;
      tilemapInt.height = win.height;
      blinkingText.resize();
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

