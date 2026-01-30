// game state

package game;

#if electron
import js.node.Fs;
#end
import console.Console;
import haxe.Json;
import jsui.UI;
import scenario.Timeline;
import cult.Cult;
import const.ItemsConst;
import const.Jobs;
import ai.*;

@:expose
class Game extends _SaveObject
{
  static var _ignoredFields = [ 'importantMessagesEnabled', 'region',
    'area', 'areaGenerator', 'jobs',
  ];
  public static var inst: Game;
  public var config: Config; // game config
  public var profile: Profile; // user profile
  public var scene: GameScene; // ui scene (hashlink OLD)
  public var ui: UI; // new (js)
  public var timeline: Timeline; // scenario timeline
  public var goals: Goals; // game.goals
  public var world: World; // game world
  public var managerWorld: WorldManager; // game world manager
  public var region: RegionGame; // region info link
  public var group: Group; // conspiracy group - antags
  public var console: Console; // game console
  public var jobs: Jobs; // job helper

  public var areaGenerator: AreaGenerator; // generator link
  public var area: AreaGame; // current area link
  public var managerArea: AreaManager; // area event manager
  public var debugArea: DebugArea; // debug actions (area mode)

  public var managerRegion: RegionManager; // event manager (region mode)
  public var playerRegion: PlayerRegion; // game player (region mode)
  public var cults: Array<Cult>; // cults list (player cult ALWAYS exists and is cults[0])

  public var player: Player; // game player
  public var playerArea: PlayerArea; // game player (area mode)
  public var location(default, null): _LocationType; // player location type - area, region, world

  public var turns: Int; // number of turns passed since game start
  public var isInited: Bool; // is the game initialized?
  public var isStarted: Bool; // has the gameplay started?
  public var state: _GameState; // current game state
  public var messageList: List<_LogMessage>; // last X messages of log
  public var hudMessageList: List<_LogMessage>; // last X messages of hud log
  public var importantMessagesEnabled: Bool; // messages enabled?
  public var scenarioStringID: String; // short name for scenario
  public var firstEverRun: Bool; // game started for the very first time

  public function new()
    {
      inst = this;
      ItemsConst.init(this);
      config = new Config(this);
      profile = new Profile(this);
      ui = new UI(this);
      cult.ordeals.profane.ProfaneConst.init();
      scene = new GameScene(this);
      console = new Console(this);
      jobs = new Jobs(this);
      managerWorld = new WorldManager(this);
      areaGenerator = new AreaGenerator(this);
      messageList = new List();
      hudMessageList = new List();
      importantMessagesEnabled = true;
      isInited = false;
      isStarted = false;
      state = GAMESTATE_RUNNING;
      scenarioStringID = 'alien';

      area = null;
      region = null;
      __Math.game = this;
    }

// partial game init to not break stuff
  public function initFake()
    {
      world = new World(this);
      world.generate();
      region = world.get(0);
      area = region.getRandom({ type: AREA_CITY_LOW, noEvents: true });
      timeline = new Timeline(this);
      timeline.create();
    }

// init game stuff
  public function init(firstTime: Bool)
    {
      trace('init');
      var scen = '';
      if (scenarioStringID == 'alien')
        scen = '[scenario a]';
      else if (scenarioStringID == 'sandbox')
        scen = '[sandbox]';
      var s = 'Parasite v' + Version.getVersion() + ' ' + Const.smallgray(scen);
//        ' (build: ' + Version.getBuild() + ')';
#if demo
      log (s + ' DEMO');
#else
      log(s);
#end
      log('<font style="font-size: 6px">Revulsion is a striking color in my palette.</font>', COLOR_DEBUG);
      turns = 0;
      state = GAMESTATE_RUNNING;
      isInited = false;

      player = new Player(this);
      group = new Group(this);
      managerArea = new AreaManager(this);
      playerArea = new PlayerArea(this);
      debugArea = new DebugArea(this);
      managerRegion = new RegionManager(this);
      playerRegion = new PlayerRegion(this);
      cults = [];
      var cult = new Cult(this);
      cult.isPlayer = true;
      cults.push(cult);

      // generate world
      world = new World(this);
      world.generate();

      // generate timeline from a scenario
      timeline = new Timeline(this);
      goals = new Goals(this);
      timeline.create();

      // set random region (currently only 1 at all)
      region = world.get(0);

      if (scenarioStringID == 'sandbox') // skip init for sandbox
        {
          // random low-population area
          area = region.getRandom({ type: AREA_CITY_LOW, noEvents: true });
        }
      else
        {
          // find random inhabited area near player starting location
          var event = timeline.getStartEvent();

          // at first we try to find low-population area for easier start
          area = region.getRandomAround(event.location.area, {
            isInhabited: true,
            minRadius: 2,
            maxRadius: 5,
            type: AREA_CITY_LOW,
            canReturnNull: true
          });

          // but if no areas found, backup plan - use any inhabited area
          if (area == null)
            area = region.getRandomAround(event.location.area, {
              isInhabited: true,
              minRadius: 2,
              maxRadius: 5
            });
        }

      // TODO: REMOVE TEST!!!
//      area = region.getRandomWithType(AREA_FACILITY, false);
//      player.vars.losEnabled = false;
//      player.vars.godmodeEnabled = true;
//      @:privateAccess testArea.generate();

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

      if (!firstTime)
        {
          // initial goals
          message({
            text: 'You are alone. You are scared. You need to find a host or you will die soon.',
            img: 'event/start'
          });
          var silent = (config.skipTutorial && config.difficulty > 0);
          for (goal in const.Goals.map.keys())
            if (const.Goals.map[goal].isStarting)
              goals.receive(goal, silent ? SILENT_ALL : SILENT_NONE);
          // initial pedia articles
          var articleAdded = false;
          for (a in const.PediaConst.initialArticles)
            if (profile.addPediaArticle(a, false))
              articleAdded = true;
          if (articleAdded)
            log(Const.small('New pedia articles available.'), COLOR_PEDIA);

          // skip tutorial flag
          if (config.skipTutorial)
            skipTutorial();
        }

      updateHUD(); // update HUD state

      isInited = true;
    }

// skip starting tutorial
  function skipTutorial()
    {
      // only with overall difficulty
      if (config.difficulty == 0)
        {
          system('Cannot skip tutorial with overall difficulty unset.');
          return;
        }
      importantMessagesEnabled = false;
      goals.complete(GOAL_TUTORIAL_ALERT);
      goals.complete(GOAL_TUTORIAL_BODY);
      goals.complete(GOAL_TUTORIAL_BODY_SEWERS);
      goals.complete(GOAL_TUTORIAL_ENERGY);
      goals.complete(GOAL_TUTORIAL_AREA_ALERT);
      goals.complete(GOAL_INVADE_HOST);
      goals.complete(GOAL_INVADE_HUMAN);
      player.evolutionManager.addImprov(IMP_BRAIN_PROBE, 2);
      goals.complete(GOAL_EVOLVE_PROBE);
      goals.complete(GOAL_PROBE_BRAIN);
      goals.complete(GOAL_LEARN_ITEMS);
      goals.complete(GOAL_PROBE_BRAIN_ADVANCED);
      goals.complete(GOAL_LEARN_SKILLS);
      player.skills.increase(KNOW_SOCIETY, 1);
      player.skills.increase(KNOW_SOCIETY, 24);
      turns = 200;
      group.priority = 5;
      group.teamTimeout = 50;
      player.energy = 100;
      importantMessagesEnabled = true;
      system('Tutorial skipped.');
    }

// clear all game stuff
  function restartPre()
    {
      isInited = false;
      state = GAMESTATE_RUNNING;
      RegionGame._maxID = 0;
      messageList.clear();
      hudMessageList.clear();
      if (location == LOCATION_AREA)
        area.leave();
      else if (location == LOCATION_REGION)
        region.leave();
      ui.clearEvents();
      ui.hud.state = HUD_DEFAULT;
    }

// game restart
  public function restart()
    {
      restartPre();
      init(false);
      scene.draw();
    }

// get cult by id
  public function getCultByID(id: Int): Cult
    {
      for (cult in cults)
        if (cult.id == id)
          return cult;
      return null;
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

// game turn ends (wrapper)
  public function turn()
    {
      if (state != GAMESTATE_RUNNING)
        return;
#if demo
      if (turns >= 500)
        {
          finishDemo();
          return;
        }
#end
      turnInternal();
    }

// game turn ends (internal)
  function turnInternal()
    {
      // player turn
      player.turn();
      if (state != GAMESTATE_RUNNING)
        return;

      // turns counter
      turns++;

      // conspiracy group logic
      group.turn();

      // cults turn
      var cultTime = 1;
      if (location == LOCATION_REGION)
        cultTime = 5;
      for (cult in cults)
        cult.turn(cultTime);

      // AI movement
      if (location == LOCATION_AREA)
        {
          area.turn();
          scene.area.turn();
          if (state != GAMESTATE_RUNNING)
            return;

          // area turn
          managerArea.turn();
          if (state != GAMESTATE_RUNNING)
            return;

          // goals turn
          goals.turn();
          if (state != GAMESTATE_RUNNING)
            return;

          // update AI visibility to player
          area.updateVisibility();
        }

      else if (location == LOCATION_REGION)
        {
          region.turn();
          if (state != GAMESTATE_RUNNING)
            return;

          // goals turn
          goals.turn();
          if (state != GAMESTATE_RUNNING)
            return;
        }
    }

// returns true when input should be blocked
  public inline function isInputLocked(): Bool
    {
      return state != GAMESTATE_RUNNING;
    }

// begins rebirth transition and shows the rebirth message
  public function beginRebirth(): Void
    {
      state = GAMESTATE_REBIRTH;

      // clear any active paths
      scene.area.clearPath(true);
      scene.region.clearPath(true);

      // rebirth target
      var ovumObj = region.getObjectsWithType('ovum')[0];
      var msgs = [
        'I am reborn.',
        'I live again.',
        'Birth, death and rebirth. The purifying rhythm of the universe.',
        'I am alive. Alive.',
      ];
      var msg: _MessageParams = {
        text: '<center>' + msgs[Std.random(msgs.length)] + '</center>',
        img: 'pedia/parasite'
      };

      // move player to ovum in region mode
      if (location == LOCATION_AREA)
        setLocation(LOCATION_REGION);
      playerRegion.moveTo(ovumObj.x, ovumObj.y, false);

      // repaint scene and show message
      scene.updateCamera();
      updateHUD();
      message(msg);
      scene.sounds.play('parasite-rebirth');
    }

// ends rebirth and resumes gameplay
  public function endRebirth(): Void
    {
      state = GAMESTATE_RUNNING;
      player.rebirthPost();
      updateHUD();
    }

// game finish
// result - win, lose
// condition - noHost, etc
// if result is win, text is displayed
  static var deathText = [
    'noHost' => 'You cannot survive without a host for long.',
    'noEnergy' => 'Your energy was completely depleted.',
    'noHealth' => "You have succumbed to injuries. It's not wise to go into the direct confrontation.",
    'habitatShock' => 'You have received your final shock from the habitat destruction.',
  ];
  public function finish(result: String, text: String, ?img: String = null)
    {
      state = GAMESTATE_FINISH;
      var finishText = '';

      // game lost
      if (result == 'lose')
        {
          log('You have lost the game.');
          finishText = deathText[text];
#if demo
          if (text == 'demo')
            finishText = 'Demo finished.';
#end

          // parasite death
          scene.sounds.play('parasite-die');

          log(finishText);
        }
      else
        {
          log('You have completed the game.');
          finishText = text;
          scene.sounds.play('game-win');
        }

      // add to event queue
      ui.event({
        type: UIEVENT_STATE,
        state: UISTATE_FINISH,
        obj: {
          text: finishText,
          img: img,
        }
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
  public function message(params: _MessageParams)
    {
      // set defaults
      if (params.col == null)
        params.col = 'message';
      if (params.title != null &&
          params.titleCol == null)
        params.titleCol = 'white';

      // add message to log
      log('<span class=narrative>' + Const.col(params.col, params.text) + '</span>');

      if (!importantMessagesEnabled)
        return;

      // add to event queue
      ui.event({
        type: UIEVENT_STATE,
        state: UISTATE_MESSAGE,
        obj: params
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

// return info-styled string
  public inline function infostr(s: String): String
    {
      if (config.extendedInfo)
        return Const.smalldebug(s);
      else return '';
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

// add system log entry to game log
  public function system(s: String)
    {
      log(Const.smallgray(s));
    }

// add entry to log (small and gray)
  public inline function logsg(arg)
    {
      log(Const.smallgray(arg));
    }

// add entry to log (small and hint)
  public inline function smallhint(arg)
    {
      log(Const.small(arg), COLOR_HINT);
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
      var msg: _LogMessage = {
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

// wrapper for logging failed action with sound/color
  public inline function actionFailed(msg: String)
    {
      log(msg, COLOR_HINT);
      scene.sounds.play('action-fail');
    }

// path movement/continuous actions
// called from timer
  public function update()
    {
      if (state != GAMESTATE_RUNNING)
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
      if (!isStarted ||
          state != GAMESTATE_RUNNING)
        {
          debug('Not in game.');
          return;
        }
      if (ui.hud.state == HUD_CHAT)
        {
          actionFailed('You cannot save during a conversation.');
          return;
        }
      if (area.isMissionArea())
        {
          actionFailed('You cannot save your game during a mission.');
          return;
        }
      if (player.saveDifficulty == UNSET)
        {
          ui.event({
            type: UIEVENT_STATE,
            state: UISTATE_DIFFICULTY,
            obj: 'save'
          });
          return;
        }
      if (player.vars.savesLeft < 1)
        {
          actionFailed('You cannot save anymore in this game.');
          return;
        }
      player.vars.savesLeft--;
      // SPOON: no saves limit
      if (config.spoonNoSavesLimit)
        player.vars.savesLeft = 999;
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
      var remaining = player.vars.savesLeft + ' saves';
      if (player.vars.savesLeft == 0)
        remaining = 'No saves';
      else if (player.vars.savesLeft == 1)
        remaining = 'Last save';
      log('Game saved to slot ' + slotID + '. ' + remaining + ' remaining.');
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
              fval = {
                _classID: Type.getEnumName(e),
                _isEnum: true,
                val: '' + fobj,
              }
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

// check if save exists
  public function saveExists(slotID: Int): Bool
    {
#if electron
      return Fs.existsSync('save' +
        (slotID < 10 ? '0' : '') + slotID + '.json');
#end
      return false;
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
      managerArea.loadPost();
      group.loadPost();
      if (location == LOCATION_AREA)
        {
          area.currentAreaLoadPost();
          playerArea.loadPost();
        }
      else if (location == LOCATION_REGION)
        region.enter();
      player.loadPost();
      scene.sounds.loadPost();
      for (cult in cults)
        cult.loadPost();
      scene.updateCamera();
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
          var isEnum: Bool = untyped srcval._isEnum;
          var classID: String = srcval._classID;
          // enum cases
          switch (Type.typeof(dstval)) {
            case TEnum(e):
              Reflect.setField(dst, f, initEnum(name, srcval, depth + 1));
              continue;
            default:
          }
          if (isEnum)
            {
              Reflect.setField(dst, f, initEnum(name, srcval, depth + 1));
              continue;
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
                    {
                      dsttmp.push(el);
                      continue;
                    }
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
                    dsttmp.push(initEnum(name, el, depth + 1));
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

// will init enum from src data { classID, isEnum, val }
  function initEnum(name: String, src: Dynamic, depth: Int): Dynamic
    {
      var classID: String = untyped src._classID;
      var ee = Type.resolveEnum(classID);
      if (ee == null)
        throw "No such enum: " + classID;
      return Type.createEnum(ee, untyped src.val);
    }

// will create a new class instance and populate it with data from save object
  function initObject(name: String, src: Dynamic, depth: Int): Dynamic
    {
      var isEnum: Bool = untyped src._isEnum;
      if (isEnum)
        return initEnum(name, src, depth);

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

#if demo
// finish the demo
  public function finishDemo()
    {
      message({
        text: 'Thank you for playing the demo! You can restart the game now and play it to this point again but to progress further you will need to buy the full game.',
        img: 'event/sandbox'
      });
      ui.event({
        type: UIEVENT_FINISH,
        state: null,
        obj: {
          result: 'lose',
          condition: 'demo',
        }
      });
    }
#end

// create AI by type (similar to AreaGame.spawnAI but doesn't add to area)
  public function createAI(type: String, x: Int, y: Int): AI
    {
      var ai: AI = null;
      if (type == 'agent')
        ai = new AgentAI(this, x, y);
      else if (type == 'blackops')
        ai = new BlackopsAI(this, x, y);
      else if (type == 'bum' || type == 'hobo')
        ai = new BumAI(this, x, y);
      else if (type == 'civilian' || type == 'civ')
        ai = new CivilianAI(this, x, y);
      else if (type == 'corpo')
        ai = new CorpoAI(this, x, y);
      else if (type == 'dog')
        ai = new DogAI(this, x, y);
      else if (type == 'police' || type == 'cop')
        ai = new PoliceAI(this, x, y);
      else if (type == 'prostitute' || type == 'pro')
        ai = new ProstituteAI(this, x, y);
      else if (type == 'security' || type == 'sec')
        ai = new SecurityAI(this, x, y);
      else if (type == 'scientist' || type == 'sci')
        ai = new ScientistAI(this, x, y);
      else if (type == 'smiler')
        ai = new SmilerAI(this, x, y);
      else if (type == 'soldier')
        ai = new SoldierAI(this, x, y);
      else if (type == 'team')
        ai = new TeamMemberAI(this, x, y);
      else if (type == 'thug')
        ai = new ThugAI(this, x, y);
      else throw 'createAI(): AI type [' + type + '] unknown';
      return ai;
    }

  function toString()
    {
      return 'game';
    }
}
