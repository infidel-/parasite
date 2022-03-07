// - has all links to windows and handles input

import h2d.Font;
import h2d.Interactive;
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
  var tilemapInt: Interactive; // tilemap interactive
  public var mouse: Mouse; // mouse cursor entity
  public var hud: HUD; // ingame HUD
  public var win: Window;
  public var font: Font;
  public var font40: Font;
  public var soundManager: SoundManager;
  var uiQueue: List<_UIEvent>; // gui event queue
  var uiQueuePaused: Bool; // if true, the queue is paused
  var uiQueuePrev: _UIEvent; // previous UI event
  public var state(get, set): _UIState;
  var _state: _UIState; // current HUD state (default, evolution, etc)
  var components: Map<_UIState, UIWindow>; // GUI windows (HaxeUI)
  var uiLocked: Array<_UIState>; // list of gui states that lock the player
  var uiNoClose: Array<_UIState>; // list of gui states that disable window closing
  public var atlas: Atlas; // AI tiles atlas
  public var entityAtlas: Array<Array<Tile>>; // entity graphics
  public var tileAtlas: Array<Tile>; // tile graphics
  public var controlPressed: Bool; // Ctrl key pressed?
  public var controlKey: String; // ctrl / alt
  public var shiftPressed: Bool; // Shift key pressed?
  var loseFocus: LoseFocus; // lose focus blur
  var isFullScreen: Bool; // game is in fullscreen mode?
  var firstResize: Bool; // ignore first resize
  var isFocused: Bool;

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
      super();
      isFocused = true; // may not be true but we want the game to play immediately
      win = Window.getInstance();
      win.addEventTarget(onEvent);
//      win.addResizeEvent(resize);
      isFullScreen = false;
      firstResize = true;
      game = g;
      uiLocked = [];
      uiNoClose = [];
      _state = UISTATE_DEFAULT;
      uiQueue = new List();
      uiQueuePaused = false;
      uiQueuePrev = null;
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
      font = hxd.Res.load('font/OrkneyRegular' +
        game.config.fontSize + '.fnt').to(hxd.res.BitmapFont).toFont();
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

      // init GUI
      mouse = new Mouse(game);
      hud = new HUD(game);
      createComponents();

      uiLocked = [ UISTATE_DIFFICULTY, UISTATE_YESNO, UISTATE_DOCUMENT ];
      uiNoClose = [ UISTATE_DEFAULT, UISTATE_YESNO, UISTATE_DIFFICULTY ];
      area = new AreaView(this);
      region = new RegionView(this);

      // add screen-sized tilemap interactive object
      tilemapInt = new h2d.Interactive(win.width, win.height);
      this.add(tilemapInt, Const.LAYER_TILEMAP);
      tilemapInt.onClick = function (e: hxd.Event)
        { mouse.onClick(e.button); }

      // init sound
      soundManager = new SoundManager(this);

      // init game state
      game.init();

      // update AI hear, view distance
      // clamp so that 4k players did not have it hard
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
/*
#if js
      // show blur on losing focus
      // this is needed because it's too easy to press Alt, lose it and not notice it
      Browser.window.onfocus = function()
        {
          loseFocus.hide();
          soundManager.resume();
        }
      Browser.window.onblur = function()
        {
          // reset input flags
          controlPressed = false;
          shiftPressed = false;
          mouse.ignoreNextClick = true; // ignore click on screen

          loseFocus.show();
          soundManager.pause();
        }
#else
#end
*/
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
            soundManager.resume();
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
            soundManager.pause();
          }
      });
#end
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

      if (x + win.width > Const.TILE_SIZE * w)
        x = Const.TILE_SIZE * w - win.width;
      if (y + win.height > Const.TILE_SIZE * h)
        y = Const.TILE_SIZE * h - win.height;
      if (x < 0)
        x = 0;
      if (y < 0)
        y = 0;

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


// handle player input
  function handleInput(key: Int): Bool
    {
      // reload window with Ctrl-R
#if js
      if (key == Key.R && controlPressed)
        {
          js.Browser.location.reload();
          return true;
        }
#end

      // toggle gui
      if (!hud.consoleVisible())
        {
          if (key == Key.SPACE)
            {
              hud.toggle();
              return true;
            }
        }

      if (!hud.consoleVisible())
        {
/*
          // enter restarts the game when it is finished
          if (game.isFinished && key == Key.ENTER &&
              _state == UISTATE_DEFAULT)
            {
              game.restart();
              return true;
            }
*/

          // hack: disallow actions when control/alt pressed
          var ret = false;
/*
          if (!controlPressed)
            ret = handleActions(key);
          if (!ret)
            ret = handleWindows(key);
          if (!ret)
            ret = handleMovement(key);
*/

          return ret;
        }

      return false;
    }


// set new GUI state, open and close windows if needed
  public function set_state(vstate: _UIState)
    {
//      trace(vstate);
//      Const.traceStack();
      if (_state != UISTATE_DEFAULT)
        {
          if (components[_state] != null)
            components[_state].hide();
        }

      _state = vstate;
      if (_state != UISTATE_DEFAULT && components[_state] != null)
        {
          if (components[_state] != null)
            components[_state].show();

          if (_state != UISTATE_LOG)
            components[_state].scrollToBegin();
        }

      // clear old path on opening message window
      if (_state == UISTATE_MESSAGE)
        clearPath();

      return _state;
    }


// common clear path (both images and list)
  public inline function clearPath()
    {
      if (game.location == LOCATION_AREA)
        game.scene.area.clearPath(true);

      else if (game.location == LOCATION_REGION)
        game.scene.region.clearPath(true);
    }


// get GUI state
  inline function get_state(): _UIState
    {
      return _state;
    }


// add event to the GUI queue
  public function event(ev: _UIEvent)
    {
      uiQueue.add(ev);

      // no windows open, work on event immediately
      if (state == UISTATE_DEFAULT)
        closeWindow();
    }


// clear GUI queue
  public inline function clearEvents()
    {
      uiQueue.clear();
    }


// close the current window
  public function closeWindow()
    {
      // check if there are more UI events in the queue
      if (uiQueue.length > 0)
        {
          // get next event
          var ev = uiQueue.first();
          uiQueuePrev = ev;
          uiQueue.remove(ev);

          if (components[ev.state] != null)
            components[ev.state].setParams(ev.obj);

          state = ev.state;

          return;
        }

      state = UISTATE_DEFAULT;
    }


// handle opening and closing windows
  function handleWindows(key: Int): Bool
    {
      // scrolling text
      if (_state != UISTATE_DEFAULT)
        {
          // get amount of lines
          var lines = 0;
          if (key == Key.PGUP ||
            (key == Key.K && shiftPressed))
            lines = -20;
          else if (key == Key.PGDOWN ||
            (key == Key.J && shiftPressed))
            lines = 20;
          else if (key == Key.UP || key == Key.K || key == Key.NUMPAD_8)
            lines = -1;
          else if (key == Key.DOWN || key == Key.J || key == Key.NUMPAD_2)
            lines = 1;

          var win: UIWindow = cast components[_state];

          if (lines != 0)
            {
              win.scroll(lines);
              return false;
            }

          else if (key == Key.END ||
            (key == Key.G && shiftPressed))
            {
              win.scrollToEnd();
              return false;
            }

          else if (key == Key.HOME || key == Key.G)
            {
              win.scrollToBegin();
              return false;
            }
        }

      // window open
      if (!Lambda.has(uiNoClose, _state))
        {
          // close windows
          if (key == Key.ENTER || key == Key.ESCAPE) 
            closeWindow();
        }

      // ui in locked state, do not allow changing windows
      if (Lambda.has(uiLocked, _state))
        return true;

      // no windows open
      var goalsPressed =
        (key == Key.NUMBER_1 && controlPressed) || key == Key.F1;
      var inventoryPressed =
        (key == Key.NUMBER_2 && controlPressed) || key == Key.F2;
      var skillsPressed =
        (key == Key.NUMBER_3 && controlPressed) || key == Key.F3;
      var logPressed =
        (key == Key.NUMBER_4 && controlPressed) || key == Key.F4;
      var timelinePressed =
        (key == Key.NUMBER_5 && controlPressed) || key == Key.F5;
      var evolutionPressed =
        (key == Key.NUMBER_6 && controlPressed) || key == Key.F6;
      var organsPressed =
        (key == Key.NUMBER_7 && controlPressed) || key == Key.F7;
      var optionsPressed =
        (key == Key.NUMBER_8 && controlPressed) || key == Key.F8;
      var debugPressed =
        (key == Key.NUMBER_9 && controlPressed) || key == Key.F9;

      // open goals window
      if (goalsPressed)
        state = UISTATE_GOALS;

      // open inventory window (if items are learned)
      else if (inventoryPressed &&
          game.player.state == PLR_STATE_HOST &&
          game.player.host.isHuman &&
          game.player.vars.inventoryEnabled)
        state = UISTATE_INVENTORY;

      // open skills window (if skills are learned)
      else if (skillsPressed &&
          game.player.vars.skillsEnabled)
        state = UISTATE_SKILLS;

      // open message log window
      else if (logPressed)
        {
          state = UISTATE_LOG;
          var win: Log = cast components[_state];
          win.scrollToEnd();
        }

      // open timeline window
      else if (timelinePressed &&
          game.player.vars.timelineEnabled)
        state = UISTATE_TIMELINE;

      // open evolution window (if enabled)
      else if (evolutionPressed &&
          game.player.state == PLR_STATE_HOST &&
          game.player.evolutionManager.state > 0)
        state = UISTATE_EVOLUTION;

      // open organs window
      else if (organsPressed &&
          game.player.state == PLR_STATE_HOST &&
          game.player.vars.organsEnabled)
        state = UISTATE_ORGANS;

      // open options window
      else if (optionsPressed)
        state = UISTATE_OPTIONS;

#if mydebug
      // open debug window
      else if (debugPressed && !game.isFinished)
        state = UISTATE_DEBUG;
#end

      return false;
    }

/*
// handle player movement
  function handleMovement(key: Int): Bool
    {
      // game finished or window open
      if (game.isFinished || _state != UISTATE_DEFAULT)
        return false;

      var dx = 0;
      var dy = 0;

      if (key == Key.UP ||
          key == Key.NUMPAD_8)
        dy = -1;

      if (key == Key.DOWN ||
          key == Key.NUMPAD_2)
        dy = 1;

      if (key == Key.LEFT ||
          key == Key.NUMPAD_4)
        dx = -1;

      if (key == Key.RIGHT ||
          key == Key.NUMPAD_6)
        dx = 1;

      if (key == Key.NUMPAD_7)
        {
          dx = -1;
          dy = -1;
        }

      if (key == Key.NUMPAD_9)
        {
          dx = 1;
          dy = -1;
        }

      if (key == Key.NUMPAD_1)
        {
          dx = -1;
          dy = 1;
        }

      if (key == Key.NUMPAD_3)
        {
          dx = 1;
          dy = 1;
        }

      if (dx == 0 && dy == 0)
        return false;

      // area mode
      if (game.location == LOCATION_AREA)
        game.playerArea.moveAction(dx, dy);

      // area mode
      else if (game.location == LOCATION_REGION)
        game.playerRegion.moveAction(dx, dy);

      return true;
    }*/


// handle player actions
  function handleActions(key: Int): Bool
    {
      // game finished
      if (game.isFinished)
        return false;

      // actions from action menu
      var ret = false;
      for (i in 1...11)
        if (key == Key.NUMBER_0 + i)
          {
            var n = i;

            // s + number = 10 + action
            if (_inputState > 0)
              n += 10;

            if (_state == UISTATE_DEFAULT)
              hud.action(n);
            else if (components[_state] != null)
              components[_state].action(n);

            _inputState = 0;
            ret = true;
            break;
          }
      // yes/no
      if (_state == UISTATE_YESNO)
        {
          var n = 0;
          if (key == Key.Y)
            n = 1;
          else if (key == Key.N)
            n = 2;
          if (n > 0)
            {
              components[_state].action(n);
              return true;
            }
        }

      // actions by key
//      ret = hud.keyAction(key);

      if (_state == UISTATE_DEFAULT)
        {
          // skip until end of turn
          if (key == Key.NUMPAD_5 || key == Key.Z)
            {
              game.turn();

              // update HUD info
              game.updateHUD();

              ret = true;
            }

          // toggle fullscreen
          else if (key == Key.F)
            {
              isFullScreen = !isFullScreen;
#if js
              var doc = js.Browser.document;
              if (doc.fullscreenEnabled)
                {
                  var e: js.html.CanvasElement =
                    cast doc.getElementById("webgl");
                  if (isFullScreen)
                    untyped e.requestFullscreen();
                  else doc.exitFullscreen();
                }
#else
              win.setFullScreen(isFullScreen);
#end
              ret = true;
            }
        }

      // next 10 actions
      if (key == Key.S)
        {
          _inputState = 1;
          ret = true;
        }

      return ret;
    }


// check if it's time to move on path
  public function checkPath()
    {
      // path active, try to move on it
      var ret = false;
      if (game.location == LOCATION_AREA && game.playerArea.path != null)
        ret = game.playerArea.nextPath();
      else if (game.location == LOCATION_REGION &&
          game.playerRegion.target != null)
        ret = game.playerRegion.nextPath();

      if (ret)
        updateCamera();
    }


// event handling
  public function onEvent(ev: hxd.Event)
    {
      try {
        var key = 0;
        var keyUp = 0;
        switch (ev.kind)
          {
            case EKeyDown:
              key = ev.keyCode;
            case EKeyUp:
              keyUp = ev.keyCode;
            case ERelease:
              // hack: always pass-through middle click
              if (ev.button == Key.MOUSE_MIDDLE)
                mouse.onClick(ev.button);
            case EWheel:
              if (_state != UISTATE_DEFAULT)
                key = (ev.wheelDelta > 0 ? Key.DOWN : Key.UP);
            case _:
          }
//        trace(key + ' ' + keyUp);
        // toggle control
        var ctrlKey = (controlKey == 'ctrl' ? Key.CTRL : Key.ALT);
        if (key == ctrlKey)
          {
            controlPressed = true;
            return;
          }
        if (keyUp == ctrlKey)
          {
            controlPressed = false;
            return;
          }

      // toggle shift
      if (key == Key.SHIFT)
        {
          shiftPressed = true;
          return;
        }
      else if (keyUp == Key.SHIFT)
        {
          shiftPressed = false;
          return;
        }

        if (key == 0)
          return;

        // handle player input
        var ret = handleInput(key);

        // update camera position
        if (ret)
          {
//            trace('GameScene.onEvent updateCamera()');
            updateCamera();
          }
        }
      catch (e: Dynamic)
        {
          var stack = haxe.CallStack.toString(
            haxe.CallStack.exceptionStack());
#if !js
          // log to file
          var f = File.append('exceptions.txt', false);
          f.writeString('Exception: ' + e + '\n');
          f.writeString(stack + '\n');
          f.close();
#end

          // write to stdout
          trace('Exception: ' + e);
          trace(stack);
        }
    }


// handle window resize event
  public function resize()
    {
#if js
      // hack: ignore first resize on js
      if (firstResize)
        {
          firstResize = false;
          return;
        }
#end
      tilemapInt.width = win.width;
      tilemapInt.height = win.height;
      hud.resize();
      updateCamera();
      if (game.location == LOCATION_AREA)
        {
          area.update();
          game.area.updateVisibility();
        }
      else if (game.location == LOCATION_REGION)
        region.update();

      // hack: pause queue, close current window and re-create all windows
      uiQueuePaused = true;
      var prevState = state;
      if (prevState != UISTATE_DEFAULT)
        closeWindow();
      createComponents();
      uiQueuePaused = false;
      if (prevState != UISTATE_DEFAULT)
        {
          if (prevState == UISTATE_MESSAGE)
            event(uiQueuePrev);
          else state = prevState;
        }
    }


// create or re-create windows
  function createComponents()
    {
      // free old ones
      if (components != null)
        for (c in components)
          c.remove();
      if (loseFocus != null)
        loseFocus.remove();

      loseFocus = new LoseFocus(game);
      components = [
        UISTATE_MESSAGE => new Message(game),
        UISTATE_DIFFICULTY => new Difficulty(game),
        UISTATE_DOCUMENT => new Text(game),
        UISTATE_YESNO => new YesNo(game),

        UISTATE_GOALS => new Goals(game),
        UISTATE_INVENTORY => new Inventory(game),
        UISTATE_SKILLS => new Skills(game),
        UISTATE_LOG => new Log(game),
        UISTATE_TIMELINE => new Timeline(game),
        UISTATE_EVOLUTION => new Evolution(game),
        UISTATE_ORGANS => new Organs(game),
        UISTATE_DEBUG => new Debug(game),
        UISTATE_FINISH => new Finish(game),
        UISTATE_OPTIONS => new Options(game),
      ];
    }
}

