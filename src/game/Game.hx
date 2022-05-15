// game state

package game;

#if electron
import js.node.Fs;
#end
import haxe.Json;
import jsui.UI;
import scenario.Timeline;

@:expose
class Game extends _SaveObject
{
  static var _ignoredFields = [ 'importantMessagesEnabled', 'region',
    'area',
  ];
  public static var inst: Game;
  public var config: Config; // game config
  public var scene: GameScene; // ui scene (hashlink OLD)
  public var ui: UI; // new (js)
  public var timeline: Timeline; // scenario timeline
  public var goals: Goals; // game.goals
  public var world: World; // game world
  public var managerWorld: WorldManager; // game world manager
  public var region: RegionGame; // region info link
  public var group: Group; // conspiracy group - antags
  public var console: ConsoleGame; // game console

  public var area: AreaGame; // current area link
  public var managerArea: AreaManager; // area event manager
  public var debugArea: DebugArea; // debug actions (area mode)

  public var managerRegion: RegionManager; // event manager (region mode)
  public var playerRegion: PlayerRegion; // game player (region mode)

  public var player: Player; // game player
  public var playerArea: PlayerArea; // game player (area mode)
  public var location(default, null): _LocationType; // player location type - area, region, world

  public var turns: Int; // number of turns passed since game start
  public var isInited: Bool; // is the game initialized?
  public var isStarted: Bool; // has the gameplay started?
  public var isFinished: Bool; // is the game finished?
  public var messageList: List<_LogMessage>; // last X messages of log
  public var hudMessageList: List<_LogMessage>; // last X messages of hud log
  public var importantMessagesEnabled: Bool; // messages enabled?

  public function new()
    {
      inst = this;
      config = new Config(this);
      ui = new UI(this);
      scene = new GameScene(this);
      console = new ConsoleGame(this);
      managerWorld = new WorldManager(this);
      messageList = new List();
      hudMessageList = new List();
      importantMessagesEnabled = true;
      isInited = false;
      isStarted = false;

      area = null;
      region = null;
      __Math.game = this;
    }

// init game stuff - called from GameScene.init()
  public function init()
    {
      var s = 'Parasite v' + Version.getVersion();
//        ' (build: ' + Version.getBuild() + ')';
#if demo
      log (s + ' DEMO');
#else
      log(s);
#end
      log('<font style="font-size: 6px">Into the river of the Green, into the river of Unseen.</font>', COLOR_DEBUG);
      turns = 0;
      isFinished = false;
      isInited = false;

      player = new Player(this);
      group = new Group(this);
      managerArea = new AreaManager(this);
      playerArea = new PlayerArea(this);
      debugArea = new DebugArea(this);
      managerRegion = new RegionManager(this);
      playerRegion = new PlayerRegion(this);

      // generate world
      world = new World(this);
      world.generate();

      // generate timeline from a scenario
      timeline = new Timeline(this);
      goals = new Goals(this);
      timeline.create();

      // initial goals
      message('You are alone. You are scared. You need to find a host or you will die soon.');
      for (goal in const.Goals.map.keys())
        if (const.Goals.map[goal].isStarting)
          goals.receive(goal);

      // set random region (currently only 1 at all)
      region = world.get(0);

      // find random inhabited area near player starting location
      var event = timeline.getStartEvent();

      // at first we try to find low-population area for easier start
      area = region.getRandomAround(event.location.area, {
        isInhabited: true,
        minRadius: 2,
        maxRadius: 5,
        type: AREA_CITY_LOW,
        canReturnNull: true });

      // but if no areas found, backup plan - use any inhabited area
      if (area == null)
        area = region.getRandomAround(event.location.area, {
          isInhabited: true,
          minRadius: 2,
          maxRadius: 5 });
      playerRegion.createEntity(area.x, area.y);

      // make area tiles around player known
      for (yy in (area.y - 1)...(area.y + 2))
        for (xx in (area.x - 1)...(area.x + 2))
          {
            var aa = region.getXY(xx, yy);
            if (aa == null)
              continue;

            aa.isKnown = true;
          }

      location = LOCATION_AREA;
      area.enter();

      updateHUD(); // update HUD state

      isInited = true;
    }

// clear all game stuff
  function restartPre()
    {
      isInited = false;
      RegionGame._maxID = 0;
      messageList.clear();
      hudMessageList.clear();
      if (location == LOCATION_AREA)
        area.leave();
      else if (location == LOCATION_REGION)
        region.leave();
      scene.region.clearIcons();
      ui.clearEvents();
    }

// game restart
  public function restart()
    {
      restartPre();
      init();
    }


// set location
  public function setLocation(vloc: _LocationType, ?newarea: AreaGame)
    {
      // hide previous gui, despawn area, etc
      if (location == LOCATION_AREA)
        area.leave();

      else if (location == LOCATION_REGION)
        region.leave();

      location = vloc;

      // show new gui
      if (location == LOCATION_AREA)
        {
          area = region.getXY(playerRegion.x, playerRegion.y);
          if (newarea != null) // enter specified area
             area = newarea;
          area.enter();
        }

      else if (location == LOCATION_REGION)
        {
          region.updateAlertness();
          region.enter();
        }

      // center camera on player
      scene.updateCamera();
    }


// game turn ends
  public function turn()
    {
      // player turn
      player.turn();
      if (isFinished)
        return;

      // turns counter
      turns++;

      // conspiracy group logic
      group.turn();

      // AI movement
      if (location == LOCATION_AREA)
        {
          area.turn();
          if (isFinished)
            return;

          // area turn
          managerArea.turn();
          if (isFinished)
            return;

          // goals turn
          goals.turn();
          if (isFinished)
            return;

          // update AI visibility to player
          area.updateVisibility();
        }

      else if (location == LOCATION_REGION)
        {
          region.turn();
          if (isFinished)
            return;

          // goals turn
          goals.turn();
          if (isFinished)
            return;
        }
    }


// game finish
// result - win, lose
// condition - noHost, etc
  public function finish(result: String, condition: String)
    {
      isFinished = true;
      var finishText = '';

      // game lost
      if (result == 'lose')
        {
          log('You have lost the game.');
          if (condition == 'noHost')
            finishText = 'You cannot survive without a host for long.';
          else if (condition == 'noEnergy')
            finishText = 'Your energy was completely depleted.';
          else if (condition == 'noHealth')
            finishText = "You have succumbed to injuries. It's not wise to go into the direct confrontation.";
          else if (condition == 'habitatShock')
            finishText = 'You have received your final shock from the habitat destruction.';
#if demo
          else if (condition == 'demo')
            finishText = 'Demo finished.';
#end

          // parasite death
          scene.sounds.play('parasite-die', true);

          log(finishText);
        }
      else
        {
          log('You have won the game!');
          finishText = 'You have won the game.';
          scene.sounds.play('game-win', true);
        }

      // add to event queue
      ui.event({
        type: UIEVENT_STATE,
        state: UISTATE_FINISH,
        obj: finishText
      });

      // update HUD info just in case
      updateHUD();
    }


// update HUD state from game state
  public inline function updateHUD()
    {
      ui.hud.update(); // update hud state
    }


// display text message in a window
  public function message(s: String, ?col: _TextColor)
    {
      if (col == null)
        col = COLOR_MESSAGE;
      narrative(s, col);

      if (!importantMessagesEnabled)
        return;

      // add to event queue
      ui.event({
        type: UIEVENT_STATE,
        state: UISTATE_MESSAGE,
        obj: {
          text: Const.narrative(s),
          col: Const.TEXT_COLORS[col]
        }
      });
    }


// add info about stat change to game log
  public inline function infoChange(name: String, mod: Float, val: Float)
    {
      info(name + ': ' + (mod > 0 ? '+' : '') + Const.round(mod) +
        ' = ' + Const.round(val));
    }


// add info entry to game log
  public inline function info(s: String)
    {
      if (config.extendedInfo)
        log(Const.small('INFO ' + s), COLOR_DEBUG);
    }


// add debug entry to game log
  public inline function debug(s: String)
    {
#if mydebug
      log(Const.small('DEBUG ' + s), COLOR_DEBUG);
#end
    }

// add narrative entry to game log
  public function narrative(s: String, ?col: _TextColor)
    {
      log('<span class=narrative>' + s + '</span>', col);
    }

// add entry to game log
  public function log(s: String, ?col: _TextColor)
    {
      if (col == null)
        col = COLOR_DEFAULT;
//      Const.p(s);

      // called before init from config
      if (messageList == null)
        return;

      // check for same message
      var last = messageList.last();
      if (last != null && last.msg == s)
        {
          last.cnt++;
          return;
        }

      // add message to the log and minilog
      var msg = {
        msg: s,
        col: col,
        cnt: 1,
      };
      messageList.add(msg);
      if (messageList.length > 100)
        messageList.pop();
      hudMessageList.add(msg);
      if (hudMessageList.length > config.hudLogLines)
        hudMessageList.pop();

      // update HUD minilog display
      ui.hud.updateLog();
    }

// path movement/continuous actions
  public function update()
    {
      if (isFinished)
        return;
      // path active, try to move on it
      var ret = false;
      if (location == LOCATION_AREA)
        {
          if (playerArea.path != null)
            ret = playerArea.nextPath();
          else if (playerArea.currentAction != null)
            ret = playerArea.nextAction();
        }
      else if (location == LOCATION_REGION &&
          playerRegion.target != null)
        ret = playerRegion.nextPath();

      if (ret)
        scene.updateCamera();
    }

// save current game into slot
  public function save(slotID: Int)
    {
      if (!isStarted || isFinished)
        {
          debug('Not in game.');
          return;
        }
      var o: _SaveGame = {
        game: null,
        version: Version.getVersion(),
      };
      o.game = saveObject('game', this, 0);
      o.game.regionID = region.id;
      o.game.areaID = area.id;
#if electron
      Fs.writeFileSync('save' +
        (slotID < 10 ? '0' : '') + slotID + '.json',
        Json.stringify(o, null, '  '), 'utf8');
#end
      log('Game saved to slot ' + slotID + '.');
    }

// save object (recursively)
  function saveObject(name: String, o: Dynamic, depth: Int): Dynamic
    {
//      trace(name + ' ' + depth);
      if (depth > 20)
        throw 'Depth too high: ' + depth + ' ' + name;
      // basic type cases
      if (Std.isOfType(o, Int) ||
          Std.isOfType(o, Float) ||
          Std.isOfType(o, Bool) ||
          Std.isOfType(o, String))
        return o;
      if (Std.isOfType(o, Array))
        {
          var val = [];
          var tmp: Array<Dynamic> = o;
          for (el in tmp)
            val.push(saveObject(name + '[]', el, depth + 1));
          return val;
        }
      switch (Type.typeof(o)) {
        case TEnum(e):
          return {
            _classID: Type.getEnumName(e),
            _isEnum: true,
            val: '' + o,
          }
        default:
      }

      // ignored fields
      // kludge for ai/game object subclasses
      var ret: Dynamic = {};
      var cl = Type.getClass(o);
      var clname: String = null;
      if (cl != null)
        clname = untyped cl.__name__;
      ret._classID = clname;
      if (clname != null &&
          (StringTools.startsWith(clname, 'ai') ||
           StringTools.startsWith(clname, 'objects') ||
           StringTools.endsWith(clname, 'FSM')))
        {
          cl = Type.getSuperClass(cl);
          if (cl != null)
            {
              clname = untyped cl.__name__;
              // sub-subclass
              if (clname != 'ai.AI' &&
                  clname != 'objects.AreaObject')
                cl = Type.getSuperClass(cl);
    //          trace('super:' + cl);
            }
        }
      var ignoredFields: Array<String> =
        Reflect.field(cl, '_ignoredFields');

      // object, loop through fields
      for (f in Reflect.fields(o))
        {
          // circular links
          if (f == 'game')
            {
              ret._hasGame = true;
              continue;
            }
          if (f == 'ui')
            {
              ret._hasUI = true;
              continue;
            }
          var fobj: Dynamic = Reflect.field(o, f);
/*
          if (f == 'sounds')
            {
              trace(depth + ' ' + name + '.' + f + ' ' + ignoredFields + ' ' + cl + ' ' + clname);
              trace(depth + ' ' + name + '.' + f + ' ' + ignoredFields +
              ' cl:' + Type.getClass(fobj) +
              ' t:' + Type.typeof(fobj));
            }*/
          if (ignoredFields != null && Lambda.has(ignoredFields, f))
            continue;

          // enums
          var fval: Dynamic = null;
          switch (Type.typeof(fobj)) {
            case TEnum(e):
              fval = '' + fobj;
//            case TObject:
            default:
          }
/*
          var fcl = Type.getClass(fobj);
          if (fcl != null)
            trace(f + ' ' + Type.getClassName(fcl));
          else trace(f + ' null ');*/
          if (fval != null)
            1;
          else if (Std.isOfType(fobj, Int) ||
              Std.isOfType(fobj, Float) ||
              Std.isOfType(fobj, Bool) ||
              Std.isOfType(fobj, String))
            fval = fobj;
          else if (Std.isOfType(fobj, Array))
            {
              fval = [];
              var tmp: Array<Dynamic> = fobj;
              for (el in tmp)
                fval.push(saveObject(f + '[]', el, depth + 1));
            }
          else if (Std.isOfType(fobj, List))
            {
              fval = [];
              var tmp: List<Dynamic> = fobj;
              for (el in tmp)
                fval.push(saveObject(f + '[]', el, depth + 1));
            }
          else if (Std.isOfType(fobj, haxe.ds.IntMap))
            {
              fval = {};
              var tmp: Map<Int, Dynamic> = fobj;
              for (key => el in tmp)
                Reflect.setField(fval, '' + key,
                  saveObject(f + '[]', el, depth + 1));
            }
          else if (Std.isOfType(fobj, haxe.ds.StringMap))
            {
              fval = {};
              var tmp: Map<String, Dynamic> = fobj;
              for (key => el in tmp)
                Reflect.setField(fval, key,
                  saveObject(f + '[]', el, depth + 1));
            }
          // serializable objects
          else if (Std.isOfType(fobj, _SaveObject))
            fval = saveObject(f, fobj, depth + 1);
          else continue;
          Reflect.setField(ret, f, fval);
        }
      return ret;
    }

// load current game from slot
  public function load(slotID: Int)
    {
      // clear old game
      trace('====== RESTART PRE ' + area.id);
      restartPre();
      trace('====== LOAD ' + area.id);

#if electron
      try {
        var s = Fs.readFileSync('save' +
          (slotID < 10 ? '0' : '') + slotID + '.json',
          'utf8');
        var o: _SaveGame = Json.parse(s);
        loadObject(o.game, this, 'game', 0);

        // post load
        region = world.get(o.game.regionID);
        area = region.get(o.game.areaID);
      }
      catch (e: Dynamic)
        {
          ui.onError('load game: ' + e, '', -1, -1, {
            stack: haxe.CallStack.toString(haxe.CallStack.exceptionStack()),
          });
        }
#end
      // reset game stuff
      trace('====== ENTER ' + area.id);
      timeline.loadPost();
      world.loadPost();
      if (location == LOCATION_AREA)
        {
          area.currentAreaLoadPost();
          playerArea.loadPost();
        }
      else if (location == LOCATION_REGION)
        region.enter();
      player.loadPost();
      log('Game loaded from slot ' + slotID + '.');
    }

// load source object into destination object recursively
  function loadObject(src: Dynamic, dst: Dynamic, name: String, depth: Int)
    {
      for (f in Reflect.fields(src))
        {
          // ignore class ID marker
          if (f == '_classID')
            continue;
          var srcval: Dynamic = Reflect.field(src, f);
          var dstval = Reflect.field(dst, f);
          var classID: String = srcval._classID;
          // enums
          switch (Type.typeof(dstval)) {
            case TEnum(e):
              Reflect.setField(dst, f, Type.createEnum(e, srcval));
              continue;
            default:
          }

          if (Std.isOfType(srcval, Int) ||
              Std.isOfType(srcval, Float) ||
              Std.isOfType(srcval, Bool) ||
              Std.isOfType(srcval, String))
            Reflect.setField(dst, f, srcval);

          else if (
              Std.isOfType(srcval, Array) ||
              Std.isOfType(dstval, Array) ||
              Std.isOfType(dstval, List))
            {
              var dsttmp = new Array<Dynamic>();
              var srctmp: Array<Dynamic> = untyped srcval;
              for (el in srctmp)
                {
                  if (Std.isOfType(el, Int) ||
                      Std.isOfType(el, Float) ||
                      Std.isOfType(el, Bool) ||
                      Std.isOfType(el, String))
                    dsttmp.push(el);
                  // NOTE: we only use Array<Array<Int>> currently
                  else if (Std.isOfType(el, Array))
                    {
                      // assume int atm
                      dsttmp.push(el);
                      continue;
                    }
                  var elClassID: String = untyped el._classID;
                  var isEnum: Bool = untyped el._isEnum;
                  if (elClassID == null)
                    dsttmp.push(el);
                  else if (isEnum)
                    {
                      var ee = Type.resolveEnum(elClassID);
                      if (ee == null)
                        throw "No such enum: " + elClassID;
                      var dstel = Type.createEnum(ee, untyped el.val);
                      dsttmp.push(dstel);
                    }
                  else
                    {
                      var dstel = initObject(name + '.' + f + '[][]', el, depth);
                      dsttmp.push(dstel);
                    }
//                  else trace(name + '.' + f + '[][] type is unsupported (' + elClassID + ').');
                }
              if (Std.isOfType(dstval, List))
                Reflect.setField(dst, f, Lambda.list(dsttmp));
              else Reflect.setField(dst, f, dsttmp);
            }

          else if (Std.isOfType(dstval, haxe.ds.IntMap))
            {
              var dsttmp = new Map<Int, Dynamic>();
              for (ff in Reflect.fields(srcval))
                {
                  var el = Reflect.field(srcval, ff);
                  var key = Std.parseInt(ff);
                  if (Std.isOfType(el, Int) ||
                      Std.isOfType(el, Float) ||
                      Std.isOfType(el, Bool) ||
                      Std.isOfType(el, String))
                    dsttmp.set(key, el);
                  var elClassID: String = untyped el._classID;
                  if (elClassID == null)
                    dsttmp.set(key, el);
                  else
                    {
                      var dstel = initObject(name + '[' + ff + ']', el, depth);
                      dsttmp.set(key, dstel);
                    }
//                  else trace(name + '.' + f + '[] type is unsupported (' + elClassID + ').');
                }
              Reflect.setField(dst, f, dsttmp);
            }

          else if (Std.isOfType(dstval, haxe.ds.StringMap))
            {
              var dsttmp = new Map<String, Dynamic>();
              for (ff in Reflect.fields(srcval))
                {
                  var el = Reflect.field(srcval, ff);
                  if (Std.isOfType(el, Int) ||
                      Std.isOfType(el, Float) ||
                      Std.isOfType(el, Bool) ||
                      Std.isOfType(el, String))
                    dsttmp.set(ff, el);
                  var elClassID: String = untyped el._classID;
                  if (elClassID == null)
                    dsttmp.set(ff, el);
                  else
                    {
                      var dstel = initObject(name + '[' + ff + ']', el, depth);
                      dsttmp.set(ff, dstel);
                    }
//                  else trace(name + '.' + f + '[] type is unsupported (' + elClassID + ').');
                }
              Reflect.setField(dst, f, dsttmp);
            }
          else if (Std.isOfType(dstval, _SaveObject))
            {
              loadObject(srcval, dstval, f, depth + 1);
              Reflect.setField(dst, f, dstval);
            }
          else if (dstval == null)
            {
              dstval = initObject(name + '.' + f, srcval, depth);
              Reflect.setField(dst, f, dstval);
            }
          else trace(name + '.' + f + ' type is unsupported (' +
            classID + ').');
        }

      // common fields
      var hasUI: Bool = untyped src._hasUI;
      if (hasUI == null)
        hasUI = false;
      if (hasUI)
        dst.ui = this.ui;
      var hasGame: Bool = untyped src._hasGame;
      if (hasGame == null)
        hasGame = false;
      if (hasGame)
        dst.game = this;
    }

// will create a new class instance and populate it with data from save object
  function initObject(name: String, src: Dynamic, depth: Int): Dynamic
    {
      // common fields
      var hasUI: Bool = untyped src._hasUI;
      if (hasUI == null)
        hasUI = false;
      var hasGame: Bool = untyped src._hasGame;
      if (hasGame == null)
        hasGame = false;

      var srcClassID: String = untyped src._classID;
      var srcClass = Type.resolveClass(srcClassID);
      if (srcClass == null)
        throw 'Could not resolve class ' + srcClassID + ' src:' + src;
      var dst = Type.createEmptyInstance(srcClass);
      if (hasGame)
        dst.game = this;
      if (hasUI)
        dst.ui = this.ui;
      if (dst.init != null)
        dst.init();
      else trace('no init for ' + name);
      loadObject(src, dst, name, depth + 1);
      if (dst.initPost != null)
        dst.initPost(true);
      return dst;
    }


  function toString()
    {
      return 'game';
    }
}
