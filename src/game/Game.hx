// game state

package game;

import console.Console;
import ui.UI;
import scenario.Timeline;
import cult.Cult;
import cult.RivalCult;
import const.ItemsConst;
import const.Jobs;
import const.Lang;
import ai.*;
import mods.ModEventRegistry;

@:expose
class Game extends _SaveObject
{
  static var _ignoredFields = [ 'importantMessagesEnabled', 'region',
    'area', 'areaGenerator', 'jobs', 'lang',
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
  public var lang: Lang; // language helper

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
  public var lastAutosaveTurn: Int = 0; // turns value at last autosave (throttle)
  public var saveSlotPending: Int = 1; // slot awaiting the first-save difficulty pick
  public var isInited: Bool; // is the game initialized?
  public var isStarted: Bool; // has the gameplay started?
  public var state: _GameState; // current game state
  public var messageList: List<_LogMessage>; // last X messages of log
  public var hudMessageList: List<_LogMessage>; // last X messages of hud log
  public var importantMessagesEnabled: Bool; // messages enabled?
  public var scenarioStringID: String; // short name for scenario
  public var firstEverRun: Bool; // game started for the very first time
  // per-mod savegame-scoped data buckets; mods read/write via parasite.savedata
  // (mods.ModSaveData facade). serialized as part of the game save, namespaced
  // by mod id so two mods never collide
  public var modData: Dynamic;

  public function new()
    {
      inst = this;
      ItemsConst.init(this);
      const.PediaConst.init(this);
      config = new Config(this);
      profile = new Profile(this);
      // mod asset overrides must populate before UI ctor — UI eagerly builds
      // every window subclass, baking borderImage url() strings via AssetPath.resolve
      mods.ModLoader.preInit(this);
      ui = new UI(this);
      cult.ordeals.profane.ProfaneConst.init();
      scene = new GameScene(this);
      console = new Console(this);
      jobs = new Jobs(this);
      lang = new Lang(this);
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
      modData = {};
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

      ui.hud.goals.rebuild(); // show starting goals instantly (no animation)
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
  public function restartPre()
    {
      isInited = false;
      state = GAMESTATE_RUNNING;
      RegionGame._maxID = 0;
      Cult._maxID = 0;
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

// get rival cult by ID
  public function getRivalCultByID(id: Int): RivalCult
    {
      for (rival in getRivalCults())
        if (rival.id == id)
          return rival;
      return null;
    }

// get all non-player rival cults
  public function getRivalCults(?activeOnly: Bool = false): Array<RivalCult>
    {
      var rivals: Array<RivalCult> = [];
      for (i in 0...cults.length)
        {
          var cult = cults[i];
          if (i == 0)
            continue;
          if (!Std.isOfType(cult, RivalCult))
            continue;
          var rival: RivalCult = cast cult;
          if (!rival.isPlayer &&
              rival.rivalTemplate != '' &&
              (!activeOnly || rival.state == CULT_STATE_ACTIVE))
            rivals.push(rival);
        }
      return rivals;
    }

// set location
  public function setLocation(vloc: _LocationType, ?newarea: AreaGame)
    {
      // hide previous gui, despawn area, etc
      if (location == LOCATION_AREA &&
          vloc != LOCATION_AREA)
        {
          if (ui.hud.state == HUD_TARGETING)
            ui.hud.targeting.exit(false);
          else if (ui.hud.state == HUD_BASE_BUILDING)
            ui.hud.state = HUD_DEFAULT;
          ui.hud.targeting.clearTarget();
        }
      if (location == LOCATION_AREA)
        {
          // mod event: leaving area (fires before location switches)
          ModEventRegistry.fire(ModEventRegistry.AREA_LEAVE, {
            game: this,
            area: area,
          });
          autosave(); // exit-save safety net (throttled)
          area.leave();
        }

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
          // mod event: entered area
          ModEventRegistry.fire(ModEventRegistry.AREA_ENTER, {
            game: this,
            area: area,
          });
          autosave(); // exit-save safety net (throttled)
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
      // mod event: turn about to run (before player acts / counter increment)
      ModEventRegistry.fire(ModEventRegistry.TURN_PRE, {
        game: this,
        turn: turns,
      });

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
        cult.turnInternal(cultTime);

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

      // mod event: turn fully processed (skipped on early-return abort above)
      ModEventRegistry.fire(ModEventRegistry.TURN_POST, {
        game: this,
        turn: turns,
      });
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
    'corNefandum' => 'Cor Nefandum is destroyed. <span class=cult>Cultus Carnis</span> dies its final death.',
  ];
  public function finish(p: _FinishParams)
    {
      state = GAMESTATE_FINISH;
      var finishText = '';

      // run is over: drop the exit-save so it can't be reloaded post-death
#if electron
      HostBridge.saveDelete(AUTOSAVE_SLOT);
#end

      // game lost
      if (p.result == 'lose')
        {
          log('You have lost the game.');
          finishText = deathText[p.text];
#if demo
          if (p.text == 'demo')
            finishText = 'Demo finished.';
#end

          // parasite death
          scene.sounds.play('parasite-die');

          log(finishText);
        }
      else
        {
          log('You have completed the game.');
          finishText = p.text;
          scene.sounds.play('game-win');
        }

      // mod event: let mods override finish-screen text/image before the UI
      // window is shown. payload is mutable; we read back text/img after fire
      var payload: Dynamic = {
        game: this,
        result: p.result,
        text: finishText,
        img: p.img,
        filter: p.filter,
      };
      ModEventRegistry.fire(ModEventRegistry.GAME_FINISH_PRE, payload);

      // add to event queue
      ui.event({
        type: UIEVENT_STATE,
        state: UISTATE_FINISH,
        obj: {
          result: p.result,
          text: payload.text,
          img: payload.img,
          filter: payload.filter,
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
      if (Const.isDebug)
        log(Const.small('DEBUG ' + s), COLOR_DEBUG);
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
        turn: turns,
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
      if (ui.hud.state == HUD_TARGETING)
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
      if (player.inMissionArea())
        {
          actionFailed('You cannot save your game during a mission.');
          return;
        }
      if (player.saveDifficulty == UNSET)
        {
          // remember which slot this save targets; restored after the pick
          saveSlotPending = slotID;
          ui.event({
            type: UIEVENT_STATE,
            state: UISTATE_DIFFICULTY,
            obj: 'save'
          });
          return;
        }
      // NOOB save difficulty: unlimited saves (no cap, no decrement)
      if (player.saveDifficulty != NOOB &&
          player.vars.savesLeft < 1)
        {
          actionFailed('You cannot save anymore in this game.');
          return;
        }
      if (player.saveDifficulty != NOOB)
        player.vars.savesLeft--;
      // SPOON: no saves limit
      if (config.spoonNoSavesLimit)
        player.vars.savesLeft = 999;
      Saver.save(this, slotID);
      if (player.saveDifficulty == NOOB)
        {
          log('Game saved to slot ' + slotID + '. Unlimited saves.');
          return;
        }
      var remaining = player.vars.savesLeft + ' saves';
      if (player.vars.savesLeft == 0)
        remaining = 'No saves';
      else if (player.vars.savesLeft == 1)
        remaining = 'Last save';
      log('Game saved to slot ' + slotID + '. ' + remaining + ' remaining.');
    }

// reserved autosave slot (exit-save safety net); manual slots are 1..MANUAL_SLOTS
  public static inline var AUTOSAVE_SLOT = 0;
  public static inline var MANUAL_SLOTS = 8;
  static inline var AUTOSAVE_THROTTLE = 20; // min turns between throttled autosaves

// autosave to the reserved slot (area enter/leave, quit). difficulty-independent:
// bypasses the savesLeft economy entirely so it works even on NOOB. throttled to
// AUTOSAVE_THROTTLE turns unless force=true (quit). respects the same
// not-allowed-to-save states as manual save (mission/chat/not-running).
  public function autosave(force: Bool = false)
    {
      if (!isStarted ||
          state != GAMESTATE_RUNNING ||
          ui.hud.state == HUD_CHAT ||
          player.inMissionArea())
        return;
      if (!force &&
          turns - lastAutosaveTurn < AUTOSAVE_THROTTLE)
        return;
      Saver.save(this, AUTOSAVE_SLOT);
      lastAutosaveTurn = turns;
      log('Autosaved.', COLOR_HINT);
    }

// check if save exists
  public function saveExists(slotID: Int): Bool
    {
      return Saver.exists(slotID);
    }

// load current game from slot
  public function load(slotID: Int)
    {
      // if save's mod snapshot differs from currently-enabled set, prompt user before destructive load.
      var saveMods = Loader.peekActiveMods(slotID);
      var warnings = mods.ModRegistry.diffSaveMods(saveMods);
      if (warnings.length == 0)
        {
          Loader.load(this, slotID);
          applyLoaded();
          return;
        }

      // build warning message
      var buf = new StringBuf();
      buf.add('This save was made with a different mod set:<br><br>');
      for (w in warnings)
        {
          if (w.kind == 'missing')
            buf.add(Const.smallgray('- <b>' + w.id + ' v' + w.saveVersion +
              '</b> was active when saved but is no longer enabled<br>'));
          else if (w.kind == 'added')
            buf.add(Const.smallgray('- <b>' + w.id + ' v' + w.activeVersion +
              '</b> is now enabled but was not when saved<br>'));
          else if (w.kind == 'mismatch')
            buf.add(Const.smallgray('- <b>' + w.id + '</b> version differs: save v' +
              w.saveVersion + ', active v' + w.activeVersion + '<br>'));
        }
      buf.add('<br>State may be inconsistent or load may fail. Load anyway?');
      var self = this;
      ui.event({
        type: UIEVENT_STATE,
        state: UISTATE_YESNO,
        obj: {
          text: buf.toString(),
          func: function(yes: Bool) {
            if (!yes) return;
            Loader.load(self, slotID);
            self.applyLoaded();
          }
        }
      });
    }

// post-load HUD refresh shared by both sync and deferred load paths
  function applyLoaded()
    {
      // a loaded game is a started game (isStarted is not persisted); without this
      // the main menu's ESC-to-close is suppressed after loading (treated as boot menu)
      isStarted = true;
      ui.hud.goals.rebuild(); // resync goal rows to the loaded model (no animation)
      ui.hud.update();
      scene.draw();
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
      else if (type == 'firmus')
        ai = new FirmusCustosAI(this, x, y);
      else if (type == 'mordax')
        ai = new MordaxCustosAI(this, x, y);
      else if (type == 'choirOfDiscord' ||
          type == 'choir' ||
          type == 'choir of discord')
        ai = new ChoirOfDiscord(this, x, y);
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
      else
        {
          // fall through to mod-registered AI types (api.registerAI)
          var cls = mods.ModContentRegistry.aiTypes.get(type);
          if (cls == null)
            throw 'createAI(): AI type [' + type + '] unknown';
          ai = Type.createInstance(cls, [this, x, y]);
        }
      return ai;
    }

  function toString()
    {
      return 'game';
    }
}
