// headless game runner: the real game logic under node with no renderer, for automated tests
//
// the entry point of ../bin/test.js, driven by tools/test.mjs, which stubs the leaf browser APIs
// (THREE, DOM, WebAudio) and supplies a seeded Math.random and an in-memory window.host. Everything
// above those leaves is the shipped code — Game, UI, GameScene, render.View — so a test here plays
// the game the player plays, through the same entry points the keyboard and the windows use.
//
// ONE RUN PER PROCESS. `--plan` prints the run ids a suite is made of and `--run <id>` plays one;
// tools/test.mjs spawns a process per id and pools them over the cores. A process is the only
// clean slate there is: a game played before another in the same process leaves static state the
// next one rolls differently from (measured: the s1 preset, then s11, drew a different timeline
// than s11 alone), and a failure that only happens after another run cannot be replayed from its id.
// See tests/README.md.

package test;

import game.Game;

class Headless
{
  static var argv: Array<String>;
  static var game: Game;
  static var failures: Array<String> = [];
  // the console stage presets (console.Stage) a fuzz run can start from instead of a new game
  static var STAGES = [ 's1', 's11', 's12', 's2', 's21', 's22', 's23', 's24', 's25', 's3', 's31' ];
  // the start points that are a new game: the alien scenario, the sandbox, and the alien scenario
  // with every mod in parasite/dev on (tools/test.mjs lists them)
  static var NEW_GAMES = [ 'new', 'sandbox', 'mods' ];
  // steps without a turn passing before a run counts as stuck
  static inline var STUCK = 300;
  // exit codes the runner reads: a known failure (tests/known.json) is reported but not counted
  static inline var EXIT_FAILED = 1;
  static inline var EXIT_KNOWN = 3;
  static inline var EXIT_STALLED = 4; // the tutorial bot did not reach its goal: tallied, not failed
  // the goal policy's chain, each reported with the turn a tutorial run reached it on
  static var MILESTONES: Array<_Goal> = [
    GOAL_INVADE_HUMAN,
    GOAL_LEARN_SOCIETY,
    GOAL_ENTER_SEWERS,
    GOAL_TRAVEL_EVENT,
    GOAL_LEARN_CLUE,
    GOAL_LEARN_NPC,
    GOAL_EVOLVE_ORGAN,
    GOAL_GROW_ORGAN,
    GOAL_EVOLVE_MICROHABITAT,
    GOAL_CREATE_HABITAT,
    GOAL_USE_COMPUTER,
    GOAL_PROGRESS_TIMELINE,
    SCENARIO_ALIEN_FIND_SHIP,
  ];
  // the endgame's chain, from the ship found to the end of the game (FINISH, printed on its own)
  static var ENDGAME_MILESTONES: Array<_Goal> = [
    SCENARIO_ALIEN_STEAL_SHIP,
    SCENARIO_ALIEN_ENTER_SHIP,
    SCENARIO_ALIEN_MISSION_ABDUCTION,
    SCENARIO_ALIEN_MISSION_LIQUIDATION,
    SCENARIO_ALIEN_MISSION_INTEL,
    SCENARIO_ALIEN_MISSION_ABDUCTION_GO_SPACESHIP,
    SCENARIO_ALIEN_MISSION_SUCCESS_GO_SPACESHIP,
    SCENARIO_ALIEN_MISSION_FAILURE_GO_SPACESHIP,
  ];
  // the chain play() tallies for a goal run: the tutorial's, or the endgame's
  static var milestones = MILESTONES;
  // the in-memory save slots the runs use
  static inline var FIXTURE_SLOT = 5;
  static inline var ROUNDTRIP_SLOT = 93;

  static function main()
    {
      argv = js.Syntax.code("process.argv");
      // the game's own traces (one per area generated, per profile miss) bury the report
      if (!has('--trace'))
        haxe.Log.trace = function(v, ?infos) {};
      if (has('--plan'))
        {
          var ids = plan();
          if (ids == null)
            {
              log('[test] unknown --suite: ' + strArg('--suite', 'all'));
              exit(2);
              return;
            }
          log(haxe.Json.stringify(ids));
          exit(0);
          return;
        }
      var id = strArg('--run', null);
      if (id == null)
        {
          log('[test] run through tools/test.mjs: --plan, or --run <id>');
          exit(2);
          return;
        }

      // the mods a fixture was saved with load asynchronously, as they do at the menu
      boot().then(function(_) {
        try
          {
            dispatch(id);
          }
        catch (e: haxe.Exception)
          {
            log('[test] ' + id + ' threw outside a step: ' + e.details());
            exit(1);
          }
      });
    }

// run one id
  static function dispatch(id: String)
    {
      var parts = id.split(':');
      if (parts[0] == 'smoke')
        smoke(Std.parseInt(parts[1]), Std.parseInt(parts[2]));
      else if (parts[0] == 'fuzz')
        {
          fuzz(id, parts[1], Std.parseInt(parts[2]), Std.parseInt(parts[3]));
          return;
        }
      // loc:<language>:<start>:<seed>:<steps>, the language served to Loc by tools/test.mjs
      else if (parts[0] == 'loc')
        {
          fuzz(id, parts[2], Std.parseInt(parts[3]), Std.parseInt(parts[4]));
          return;
        }
      else if (parts[0] == 'roundtrip')
        roundtrip(parts[1], Std.parseInt(parts[2]), Std.parseInt(parts[3]));
      else if (parts[0] == 'continue')
        {
          continueRun(id, parts[1], Std.parseInt(parts[2]), Std.parseInt(parts[3]), Std.parseInt(parts[4]));
          return;
        }
      else if (parts[0] == 'tutorial')
        {
          tutorial(id, parts[1], Std.parseInt(parts[2]), Std.parseInt(parts[3]));
          return;
        }
      else if (parts[0] == 'endgame')
        {
          endgame(id, parts[1], Std.parseInt(parts[2]), Std.parseInt(parts[3]));
          return;
        }
      else
        {
          log('[test] unknown run id: ' + id);
          exit(2);
          return;
        }
      finish(id);
    }

// the run ids of the suite asked for; --quick is the cut `cd src && make` runs on every build.
// a START is `new` (a new game), a stage preset (`s21`) or a fixture save (`save/<file>`)
  static function plan(): Array<String>
    {
      var quick = has('--quick');
      var suite = strArg('--suite', 'all');
      var seed0 = intArg('--seed', 1);
      var count = intArg('--count', quick ? 5 : 20);
      var steps = intArg('--steps', quick ? 200 : 1000);
      var start = strArg('--start', null);
      var fixtures: Array<String> = js.Syntax.code("host.fixtures");
      var saves = [ for (f in fixtures) 'save/' + f ];
      // the quick cut loads three fixtures: the oldest, one in the old save format (2) and the newest
      // that loads without mods
      var quickSaves = [ for (f in saves) if (f.indexOf('-v0.19.') > 0 ||
        f.indexOf('habitat-cult-base') > 0 ||
        f.indexOf('region-corp-cult1') > 0) f ];
      var all = (suite == 'all');
      if (!all &&
          suite != 'smoke' &&
          suite != 'fuzz' &&
          suite != 'compat' &&
          suite != 'roundtrip' &&
          suite != 'continue' &&
          suite != 'loc' &&
          suite != 'endgame' &&
          suite != 'tutorial')
        return null;
      var ids = [];
      if (all ||
          suite == 'smoke')
        ids.push('smoke:' + seed0 + ':' + count);
      // random play from new games and the stage presets: the quick cut plays every start point
      // once, the soak each of them on every seed
      if (all ||
          suite == 'fuzz')
        for (st in (start != null ? start.split(',') : NEW_GAMES.concat(STAGES)))
          for (i in 0...(quick ? 1 : count))
            ids.push('fuzz:' + st + ':' + (seed0 + i) + ':' + steps);
      // every fixture loads (old saves too) and plays on
      if (all ||
          suite == 'compat')
        for (st in (start != null ? start.split(',') : (quick ? quickSaves : saves)))
          ids.push('fuzz:' + st + ':' + seed0 + ':' + (quick ? 50 : 200));
      // save, load, save again: the two saves must match
      if (all ||
          suite == 'roundtrip')
        for (st in (start != null ? start.split(',') : (quick ? [ 'new', 's2' ].concat(quickSaves) : [ 'new' ].concat(STAGES).concat(saves))))
          ids.push('roundtrip:' + st + ':' + seed0 + ':' + (quick ? 20 : 50));
      // a quiet save loaded in a fresh process plays on as the game that made it does. From the
      // presets only, and early: random play ends a new game (and most presets) before 200 steps
      if (all ||
          suite == 'continue')
        for (st in (start != null ? start.split(',') : (quick ? [ 's1', 's2' ] : STAGES)))
          for (i in 0...(quick ? 1 : 3))
            ids.push('continue:' + st + ':' + (seed0 + i) + ':30:' + (quick ? 50 : 100));
      // random play in French and in the pseudo locale; the runner plays each one's English twin
      // and compares their saves
      if (all ||
          suite == 'loc')
        for (lang in [ 'fr', 'pseudo' ])
          for (st in (start != null ? start.split(',') : (quick ? [ (lang == 'fr' ? 's1' : 's2') ] : NEW_GAMES.concat(STAGES))))
            ids.push('loc:' + lang + ':' + st + ':' + seed0 + ':' + (quick ? 200 : 500));
      // the goal policy through the tutorial, the timeline and the habitat, on every seed, and on
      // twice the seeds in the soak: 20 leave the computer goal at two runs, too thin to gate on.
      // the quick cut stops at the remembered event area, which about half the seeds reach
      if (all ||
          suite == 'tutorial')
        for (i in 0...(quick ? count : 2 * count))
          ids.push('tutorial:' + strArg('--goal', quick ? 'GOAL_TRAVEL_EVENT' : 'SCENARIO_ALIEN_FIND_SHIP') + ':' + (seed0 + i) + ':' +
            (quick ? 2000 : 4000));
      // the goal policy from the ship found (s3) and ready to start (s31) to the end of the game
      if (!quick &&
          (all ||
           suite == 'endgame'))
        for (st in (start != null ? start.split(',') : [ 's3', 's31' ]))
          for (i in 0...count)
            ids.push('endgame:' + st + ':' + (seed0 + i) + ':3000');
      return ids;
    }

// report a run's failures and exit with its code
  static function finish(id: String)
    {
      if (failures.length == 0)
        {
          exit(0);
          return;
        }
      // each failure is filed on its own: a run is known only when every one of them is
      var unknown = [];
      for (f in failures)
        {
          var knownAs = knownMatch(f);
          if (knownAs == null)
            unknown.push(f);
          else if (f.indexOf('both saves:') < 0)
            log('known ' + id + ': ' + f.split('\n')[0] + ' (' + knownAs + ')');
        }
      // the pointer to the two saves is a failure only alongside one
      if (unknown.length == 1 &&
          unknown[0].indexOf('both saves:') >= 0)
        unknown = [];
      if (unknown.length == 0)
        {
          exit(EXIT_KNOWN);
          return;
        }
      log(id + ': ' + unknown.join('\n  '));
      exit(EXIT_FAILED);
    }

// where a failure is filed, when tests/known.json has an entry one of whose `match` strings it
// contains
  static function knownMatch(text: String): String
    {
      // the runner's parse of tests/known.json: untyped JSON off disk, [{ match: [..], todo }]
      var list: Array<Dynamic> = js.Syntax.code("host.known");
      for (k in list)
        {
          var matches: Array<String> = k.match;
          for (m in matches)
            if (text.indexOf(m) >= 0)
              return k.todo;
        }
      return null;
    }

// build the game object graph the way Main.init does, minus the canvas, the shader warm and the menu
  static function boot(): js.lib.Promise<Dynamic>
    {
      Const.isDebug = HostBridge.isDebug;
      game = new Game();
      ai.CommonLogic.game = game;
      ai.DefaultLogic.game = game;
      ai.FollowerLogic.game = game;
      ai.CommandLogic.game = game;
      game.scene.init();
      // Sounds builds its library on soundmanager's onready, which the stub never fires. it matters
      // to logic only through Std.random: a play rolls its variant, as it does live
      @:privateAccess game.scene.sounds.init();
      return mods.ModLoader.load(game);
    }

// start a new game on this seed, as ui.NewGame.newGame does
  public static function newGame(seed: Int, ?scenario = 'alien')
    {
      prepare(seed);
      game.scenarioStringID = scenario;
      game.isStarted = true;
      game.ui.closeWindow();
      game.restart();
    }

// load a fixture save from tests/saves as the Saves window does, answering the different-mods
// prompt (most fixtures were made with the chainsaw and pickpocket mods on) the way a player
// without them would: load anyway
  static function loadFixture(path: String, seed: Int)
    {
      prepare(seed);
      js.Syntax.code("host.loadFixture({0}, {1})", FIXTURE_SLOT, path);
      game.ui.closeWindow();
      game.load(FIXTURE_SLOT);
      if (game.ui.state == UISTATE_YESNO)
        @:privateAccess game.ui.components[_UIState.UISTATE_YESNO].action(1);
      if (!game.isStarted)
        throw 'the save did not load';
    }

// the state a game starts from on this seed, whether it is a new one or a load
  static function prepare(seed: Int)
    {
      Bot.seed(game, seed);
      // the path and repeat stepping is throttled by the wall clock; the tests step it themselves
      game.config.repeatDelay = 0;
      // > 0 answers every Difficulty window on its own (ui.UI.closeWindow)
      game.config.difficulty = 1 + seed % 3;
      // the gray INFO lines default to on in a debug build (Config), and to off for a player
      game.config.extendedInfo = (seed % 2 == 0);
    }

// boot every seed into its starting area, wait out a few turns, and check that a seed is a replay.
// FIVE waits: a bare parasite starves in about ten, and that ends the game
  static function smoke(seed0: Int, count: Int)
    {
      for (i in 0...count)
        {
          var seed = seed0 + i;
          run(seed, function() {
            newGame(seed);
            if (game.location != LOCATION_AREA ||
                game.area == null)
              fail(seed, 'not in an area after a new game');
            closeMessages();
            if (!game.ui.hud.keyAction('z'))
              fail(seed, 'no Wait on the first turn');
            var t0 = game.turns;
            for (_ in 0...4)
              game.ui.hud.keyAction('z');
            if (game.turns != t0 + 4)
              fail(seed, '4 waits passed ' + (game.turns - t0) + ' turns');
          });
        }

      // the same seed twice is the same game, down to the save
      var a = playAndSave(seed0);
      var b = playAndSave(seed0);
      if (a != b)
        fail(seed0, 'two runs of one seed saved differently (' + firstDiff(a, b) + ')');
      // printed so two PROCESSES can be compared too: the hash must not depend on what ran before
      log('[test] seed ' + seed0 + ' save ' + haxe.crypto.Md5.encode(a));
    }

// one random-play run: --stop N writes the state before step N as a save instead (the runner asks
// for that after a failure, in a fresh process, so the save is the run that failed)
  static function fuzz(id: String, start: String, seed: Int, steps: Int)
    {
      var stop = intArg('--stop', -1);
      var res = play(start, seed, steps, stop, null);
      if (stop >= 0)
        {
          log('    save: ' + failSave(id));
          exit(0);
          return;
        }
      if (res.failure == null)
        {
          if (id.indexOf('loc:') == 0)
            locReport(id);
          exit(0);
          return;
        }
      var buf = new StringBuf();
      buf.add('at step ' + res.step + ' (turn ' + game.turns + '): ' + res.failure);
      buf.add('\n    replay: make test args="--run ' + id + '"');
      buf.add('\n    last steps: ' + res.trail.join(' | '));
      buf.add('\n    last log: ' + logTail(8).join(' | '));
      var text = buf.toString();
      var knownAs = knownMatch(text);
      // a known failure prints one line, unless --full asks for the whole report
      if (knownAs != null &&
          !has('--full'))
        {
          log('known ' + id + ' at step ' + res.step + ': ' + res.failure.split('\n')[0] + ' (' + knownAs + ')');
          exit(EXIT_KNOWN);
          return;
        }
      log(id + ' ' + text);
      // the runner reads this and replays to the step before it, for the save
      log('@fail ' + res.step);
      exit(EXIT_FAILED);
    }

// a language run's save, with the log taken out (the only part of a save that is in the player's
// language), as a hash the runner compares with the English twin's, and the strings it missed
  static function locReport(id: String)
    {
      // the language really is the one asked for, or every check here passes in English
      if (l10n.Loc.lang() != id.split(':')[1])
        {
          log(id + ': played in ' + l10n.Loc.lang() + ', not ' + id.split(':')[1]);
          exit(EXIT_FAILED);
          return;
        }
      Saver.save(game, 90);
      // the save's own JSON parsed back: untyped by nature
      var save: Dynamic = haxe.Json.parse(HostBridge.saveRead(90));
      stripLog(save);
      var text = haxe.Json.stringify(save);
      js.Syntax.code("host.writeOut({0}, {1})", id.split(':').join('-').split('/').join('-') + '.json.gz', text);
      log('@lochash ' + haxe.crypto.Md5.encode(text));
      var missing = l10n.Loc.missingList();
      log('@locmiss ' + missing.length + ' ' + missing.slice(0, 5).join(' | '));
    }

// drop the log fields (ROUNDTRIP_IGNORE) from a parsed save, at any depth
  static function stripLog(v: Dynamic)
    {
      if (Std.isOfType(v, Array))
        {
          var a: Array<Dynamic> = v;
          for (x in a)
            stripLog(x);
        }
      else if (Reflect.isObject(v) &&
          !Std.isOfType(v, String))
        for (k in Reflect.fields(v))
          {
            if (ROUNDTRIP_IGNORE.indexOf(k) >= 0)
              Reflect.deleteField(v, k);
            else stripLog(Reflect.field(v, k));
          }
    }

// one bot game from a start point: the step it broke at and why, or no failure. stopAt >= 0
// stops cleanly before that step, which is how a failure is replayed up to the moment before. A
// goal plays the goal policy and stops the moment that goal is completed
  static function play(start: String, seed: Int, steps: Int, stopAt: Int, goal: _Goal): {
      failure: String,
      step: Int,
      trail: Array<String>,
      reached: Array<String>,
    }
    {
      var reached: Array<String> = [];
      var left = milestones.copy();
      var alerts: Array<String> = js.Syntax.code("host.alerts");
      var bot: Bot = null;
      var step = -1;
      var failure: String = null;
      var slowMS = 0.0;
      var slow = '';
      try
        {
          // a new game (`new`, `sandbox`, or `mods` with every dev mod on), a stage preset or a
          // fixture save, then the console commands chained on with `+` (`_` for a space)
          var parts = [ for (x in start.split('+')) x.split('_').join(' ') ];
          // `-` plays on from the game as it stands
          if (parts[0] == '-')
            {}
          else if (parts[0].indexOf('save/') == 0)
            loadFixture('tests/saves/' + parts[0].substr(5), seed);
          else
            {
              newGame(seed, (parts[0] == 'sandbox' ? 'sandbox' : 'alien'));
              if (NEW_GAMES.indexOf(parts[0]) < 0)
                game.console.run(parts[0]);
            }
          for (cmd in parts.slice(1))
            game.console.run(cmd);
          // one random run in four answers the Difficulty windows itself, one choice at a time
          if (goal == null &&
              seed % 4 == 0)
            game.config.difficulty = 0;
          if (alerts.length > 0)
            {
              failure = 'alert while starting from ' + start + ': ' + alerts[0];
              return {
                failure: failure,
                step: -1,
                trail: [],
                reached: reached,
              };
            }
          bot = new Bot(game, seed, (goal != null ? 'goal' : 'random'));
          var lastTurn = game.turns;
          var still = 0;
          step = 0;
          while (step < steps &&
              step != stopAt &&
              (goal == null ||
               !game.goals.completed(goal)))
            {
              var n = alerts.length;
              var t0 = haxe.Timer.stamp();
              if (!bot.step())
                break;
              var ms = (haxe.Timer.stamp() - t0) * 1000;
              if (ms > slowMS)
                {
                  slowMS = ms;
                  slow = 'step ' + step + ', turn ' + game.turns + ', ' +
                    (game.area != null ? @:privateAccess game.area._ai.length : 0) + ' AIs: ' + bot.trail[bot.trail.length - 1];
                }
              if (alerts.length > n)
                {
                  failure = 'alert: ' + alerts[n];
                  break;
                }
              var broken = bot.check();
              if (broken.length > 0)
                {
                  failure = broken.join('; ');
                  break;
                }
              // the turn each milestone of the goal policy's chain was first completed on
              if (goal != null)
                for (g in left.copy())
                  if (game.goals.completed(g))
                    {
                      reached.push(g + ' ' + game.turns);
                      left.remove(g);
                      // --save-at GOAL keeps the game as it stands then, the makings of a fixture
                      if (g == strArg('--save-at', null))
                        {
                          Saver.save(game, 90);
                          var name = id(start, seed) + '-' + g + '-t' + game.turns + '.json.gz';
                          js.Syntax.code("host.writeOut({0}, {1})", name, HostBridge.saveRead(90));
                          log('[test] saved at ' + g + ': tests/out/' + name);
                        }
                    }
              still = (game.turns == lastTurn ? still + 1 : 0);
              lastTurn = game.turns;
              if (still >= STUCK)
                {
                  failure = 'stuck: no turn passed in ' + STUCK + ' steps';
                  break;
                }
              step++;
            }
        }
      catch (e: haxe.Exception)
        {
          failure = 'threw: ' + e.details();
        }
      // the slowest step, for the runner's report
      log('@slow ' + Std.int(slowMS) + ' ' + slow);
      return {
        failure: failure,
        step: step,
        trail: (bot != null ? bot.trail : []),
        reached: reached,
      };
    }

// the goal policy through the tutorial from a new game: it reaches the goal (printing the turns it
// took, for the runner's tally), stalls (exit EXIT_STALLED with what it was on), or breaks
  static function tutorial(id: String, goal: _Goal, seed: Int, steps: Int)
    {
      var res = play('new', seed, steps, -1, goal);
      log('@milestones ' + MILESTONES.join(','));
      for (r in res.reached)
        log('@reach ' + r);
      if (res.failure != null)
        {
          fail(seed, 'at step ' + res.step + ' (turn ' + game.turns + '): ' + res.failure +
            '\n    replay: make test args="--run ' + id + '"' +
            '\n    last steps: ' + res.trail.join(' | '));
          finish(id);
          return;
        }
      if (game.goals.completed(goal))
        {
          exit(0);
          return;
        }
      var on = [ for (g in game.goals.iteratorCurrent()) g ];
      log('stalled ' + id + ' at turn ' + game.turns + ' (' + game.state + ', player ' + game.player.state +
        '), current goals: ' + on.join(', ') +
        '\n    replay: make test args="--run ' + id + '"' +
        '\n    last steps: ' + res.trail.join(' | ') +
        '\n    last log: ' + logTail(8).join(' | '));
      exit(EXIT_STALLED);
    }

// the goal policy from a start point at the ship (s3, s31) to the end of the game: the ship stolen
// and boarded, the mission, back aboard. It finishes (a win, failed mission or not), stalls, or breaks
  static function endgame(id: String, start: String, seed: Int, steps: Int)
    {
      milestones = ENDGAME_MILESTONES;
      // the last goal of every ending finishes the game, so the run stops on FINISH, not on a goal
      var res = play(start, seed, steps, -1, SCENARIO_ALIEN_MISSION_SUCCESS_GO_SPACESHIP);
      log('@milestones ' + ENDGAME_MILESTONES.join(',') + ',FINISH');
      for (r in res.reached)
        log('@reach ' + r);
      if (res.failure != null)
        {
          fail(seed, 'at step ' + res.step + ' (turn ' + game.turns + '): ' + res.failure +
            '\n    replay: make test args="--run ' + id + '"' +
            '\n    last steps: ' + res.trail.join(' | '));
          finish(id);
          return;
        }
      // every ending is one of the three back-aboard goals completed (game.finish, result 'win')
      if (Lambda.exists(ENDGAME_MILESTONES.slice(5), function(g) return game.goals.completed(g)))
        {
          log('@reach FINISH ' + game.turns);
          exit(0);
          return;
        }
      var on = [ for (g in game.goals.iteratorCurrent()) g ];
      log('stalled ' + id + ' at turn ' + game.turns + ' (' + game.state + ', player ' + game.player.state +
        '), current goals: ' + on.join(', ') +
        '\n    replay: make test args="--run ' + id + '"' +
        '\n    last steps: ' + res.trail.join(' | ') +
        '\n    last log: ' + logTail(8).join(' | '));
      exit(EXIT_STALLED);
    }

// play a few random steps from a start point, then save, load that save and save again: anything
// a save does not carry, or a load changes, shows up as a difference between the two
  static function roundtrip(start: String, seed: Int, steps: Int)
    {
      var res = play(start, seed, steps, -1, null);
      if (res.failure != null)
        {
          fail(seed, 'broke before the roundtrip, at step ' + res.step + ': ' + res.failure);
          return;
        }
      run(seed, function() {
        Saver.save(game, ROUNDTRIP_SLOT);
        var a = HostBridge.saveRead(ROUNDTRIP_SLOT);
        game.load(ROUNDTRIP_SLOT);
        if (game.ui.state == UISTATE_YESNO)
          @:privateAccess game.ui.components[_UIState.UISTATE_YESNO].action(1);
        Saver.save(game, ROUNDTRIP_SLOT + 1);
        var b = HostBridge.saveRead(ROUNDTRIP_SLOT + 1);
        if (a == b)
          return;
        // the save's own JSON parsed back: untyped by nature, compared field by field
        var changed = new Map<String, String>();
        diffPaths(haxe.Json.parse(a), haxe.Json.parse(b), 'save', changed);
        if (!changed.keys().hasNext())
          return;
        // both halves written out, for a closer look (tests/README.md)
        var name = 'roundtrip-' + start.split('/').join('-') + '-' + seed;
        js.Syntax.code("host.writeOut({0}, {1})", name + '-a.json.gz', a);
        js.Syntax.code("host.writeOut({0}, {1})", name + '-b.json.gz', b);
        // one failure per kind of change, so tests/known.json can file each on its own
        var paths = [ for (k in changed.keys()) k ];
        paths.sort(Reflect.compare);
        for (p in paths)
          fail(seed, 'changed across a load: ' + p + ' (e.g. ' + changed[p] + ')');
        fail(seed, 'both saves: tests/out/' + name + '-{a,b}.json.gz');
      });
    }

// a save is the whole game: play to a quiet step past k, save there, then play m steps more on a
// second seed and save again. --resume is the other half, run by tools/test.mjs in a fresh process:
// load the quiet save, play the same m steps, and save. The two last saves must match; a difference
// is state that play reads and a save drops, which roundtrip cannot see (the save it compares is the
// one it just loaded)
  static function continueRun(id: String, start: String, seed: Int, k: Int, m: Int)
    {
      var name = 'continue-' + id.split(':').join('-').split('/').join('-');
      var seed2 = seed + 1000;
      if (has('--resume'))
        {
          // the profile the first half played with, so a pedia unlock is not new again
          js.Syntax.code("host.profileText = host.readOut({0})", name + '-profile.json.gz');
          run(seed, function() loadFixture('tests/out/' + name + '-quiet.json.gz', seed));
          if (failures.length == 0)
            {
              js.Syntax.code("Math.random = {0}", gen.Rng.mulberry32(seed2));
              var res = play('-', seed2, m, -1, null);
              if (res.failure != null)
                fail(seed, 'the loaded game broke at step ' + res.step + ': ' + res.failure);
              else run(seed, function() {
                Saver.save(game, ROUNDTRIP_SLOT);
                var b = HostBridge.saveRead(ROUNDTRIP_SLOT);
                var a: String = js.Syntax.code("host.readOut({0})", name + '-a.json.gz');
                if (a == b)
                  return;
                js.Syntax.code("host.writeOut({0}, {1})", name + '-b.json.gz', b);
                var changed = new Map<String, String>();
                diffPaths(haxe.Json.parse(a), haxe.Json.parse(b), 'save', changed);
                var paths = [ for (p in changed.keys()) p ];
                paths.sort(Reflect.compare);
                for (p in paths)
                  fail(seed, 'differs after a load and ' + m + ' steps: ' + p + ' (e.g. ' + changed[p] + ')');
                if (paths.length > 0)
                  fail(seed, 'both saves: tests/out/' + name + '-{a,b}.json.gz');
              });
            }
          finish(id);
          return;
        }

      var res = play(start, seed, k, -1, null);
      if (res.failure != null)
        {
          fail(seed, 'broke before the quiet save, at step ' + res.step + ': ' + res.failure);
          finish(id);
          return;
        }
      var quiet = false;
      run(seed, function() {
        // a step with nothing under way that a save leaves out: a walk, a region trip, a repeated
        // action, a window or one queued
        var bot = new Bot(game, seed, 'random');
        for (_ in 0...100)
          {
            quiet = (game.state == GAMESTATE_RUNNING &&
              game.ui.state == UISTATE_DEFAULT &&
              game.ui.hud.state == HUD_DEFAULT &&
              @:privateAccess game.ui.uiQueue.length == 0 &&
              game.playerArea.path == null &&
              game.playerArea.currentAction == null &&
              game.playerRegion.target == null);
            if (quiet ||
                !bot.step())
              break;
          }
        if (!quiet)
          return;
        // only the stage presets switch these off, and only the Game constructor back on
        game.importantMessagesEnabled = true;
        Saver.save(game, ROUNDTRIP_SLOT);
        js.Syntax.code("host.writeOut({0}, {1})", name + '-quiet.json.gz', HostBridge.saveRead(ROUNDTRIP_SLOT));
        js.Syntax.code("host.writeOut({0}, {1})", name + '-profile.json.gz', haxe.Json.stringify(game.profile.object));
        js.Syntax.code("Math.random = {0}", gen.Rng.mulberry32(seed2));
        var res2 = play('-', seed2, m, -1, null);
        if (res2.failure != null)
          {
            fail(seed, 'broke after the quiet save, at step ' + res2.step + ': ' + res2.failure);
            return;
          }
        Saver.save(game, ROUNDTRIP_SLOT);
        js.Syntax.code("host.writeOut({0}, {1})", name + '-a.json.gz', HostBridge.saveRead(ROUNDTRIP_SLOT));
      });
      if (failures.length == 0 &&
          !quiet)
        log('[test] ' + id + ': ' + (game.state == GAMESTATE_FINISH ? 'the game ended' : 'no quiet step in 100') +
          ' before the quiet save, nothing compared');
      // the runner plays the other half
      else if (failures.length == 0)
        log('@resume');
      finish(id);
    }

// fields a load is allowed to change: it logs "Game loaded from slot N.", and visRev is the
// renderer's sightline counter (AreaGame), bumped by the load's visibility pass
  static var ROUNDTRIP_IGNORE = [ 'messageList', 'hudMessageList', 'visRev' ];

// collect the paths where two parsed saves differ, ids folded (`_list.433` is `_list.N`, `[4]` is
// `[]`) so one kind of change is one entry however many objects it touches; the value is the first
// example seen
  static function diffPaths(a: Dynamic, b: Dynamic, path: String, out: Map<String, String>)
    {
      if (Std.isOfType(a, Array) &&
          Std.isOfType(b, Array))
        {
          var x: Array<Dynamic> = a;
          var y: Array<Dynamic> = b;
          if (x.length != y.length &&
              !out.exists(path + '.length'))
            out[path + '.length'] = x.length + ' -> ' + y.length;
          for (i in 0...(x.length < y.length ? x.length : y.length))
            diffPaths(x[i], y[i], path + '[]', out);
          return;
        }
      if (Reflect.isObject(a) &&
          Reflect.isObject(b) &&
          !Std.isOfType(a, String) &&
          !Std.isOfType(b, String))
        {
          var keys = Reflect.fields(a);
          for (k in Reflect.fields(b))
            if (keys.indexOf(k) < 0)
              keys.push(k);
          for (k in keys)
            {
              if (ROUNDTRIP_IGNORE.indexOf(k) >= 0)
                continue;
              var sub = path + '.' + (~/^[0-9]+$/.match(k) ? 'N' : k);
              diffPaths(Reflect.field(a, k), Reflect.field(b, k), sub, out);
            }
          return;
        }
      if (a != b &&
          !out.exists(path))
        out[path] = short(a) + ' -> ' + short(b);
    }

// a name for a run's files: its start and seed
  static function id(start: String, seed: Int): String
    {
      return start.split('/').join('-').split('+').join('-') + '-' + seed;
    }

// a value cut down for a report line
  static function short(v: Dynamic): String
    {
      var s = Std.string(v);
      return (s.length > 40 ? s.substr(0, 40) + '...' : s);
    }

// write the current state out as a failure save; the run was stopped the step before it broke
  static function failSave(id: String): String
    {
      try
        {
          Saver.save(game, 91);
          var name = 'fail-' + id.split(':').join('-') + '.json.gz';
          js.Syntax.code("host.writeOut({0}, {1})", name, HostBridge.saveRead(91));
          return 'tests/out/' + name;
        }
      catch (e: haxe.Exception)
        {
          return 'none (saving threw: ' + e.message + ')';
        }
    }

// the last n lines of the game log, tags stripped
  static function logTail(n: Int): Array<String>
    {
      var list = [ for (m in game.messageList) ~/<[^>]*>/g.replace(m.msg, '') ];
      return list.slice(list.length > n ? list.length - n : 0);
    }

// a new game on this seed, five waits, and the save it would write
  static function playAndSave(seed: Int): String
    {
      newGame(seed);
      closeMessages();
      for (_ in 0...5)
        game.ui.hud.keyAction('z');
      Saver.save(game, 90);
      return HostBridge.saveRead(90);
    }

// close the informational windows a player would click through
  static function closeMessages()
    {
      while (game.ui.state == UISTATE_MESSAGE)
        game.ui.closeWindow();
    }

// run one seed's body, turning a throw or an alert line into a failure
  static function run(seed: Int, body: Void -> Void)
    {
      var alerts: Array<String> = js.Syntax.code("host.alerts");
      var n = alerts.length;
      try
        {
          body();
        }
      catch (e: haxe.Exception)
        {
          fail(seed, 'threw: ' + e.details());
        }
      for (i in n...alerts.length)
        fail(seed, 'alert: ' + alerts[i]);
    }

// where two strings first differ, with a little context
  static function firstDiff(a: String, b: String): String
    {
      var i = 0;
      while (i < a.length &&
          i < b.length &&
          a.charAt(i) == b.charAt(i))
        i++;
      var from = (i > 80 ? i - 80 : 0);
      return 'at ' + i + ': ' + a.substr(from, 400) + ' | ' + b.substr(from, 400);
    }

// record a failure for this seed
  static function fail(seed: Int, msg: String)
    failures.push('seed ' + seed + ': ' + msg);

  static function has(name: String): Bool
    {
      for (a in argv)
        if (a == name)
          return true;
      return false;
    }

  static function strArg(name: String, def: String): String
    {
      for (i in 0...argv.length)
        if (argv[i] == name &&
            i + 1 < argv.length)
          return argv[i + 1];
      return def;
    }

  static function intArg(name: String, def: Int): Int
    {
      var s = strArg(name, null);
      if (s == null)
        return def;
      var v = Std.parseInt(s);
      return (v == null ? def : v);
    }

// print a report line (the runner mutes console.log for the game's own chatter)
  static inline function log(s: String)
    js.Syntax.code("__out({0})", s);

// exit now: the stubbed timers the UI arms (toasts, fades) would otherwise hold node open
  static inline function exit(code: Int)
    js.Syntax.code("process.exit({0})", code);
}
