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

import game.AreaGame;
import game.Game;

class Headless
{
  static var argv: Array<String>;
  static var game: Game;
  static var failures: Array<String> = [];
  // the console stage presets (console.Stage) a fuzz run can start from instead of a new game
  static var STAGES = [ 's1', 's11', 's12', 's2', 's21', 's22', 's23', 's24', 's25', 's3', 's31' ];
  // steps without a turn passing before a run counts as stuck
  static inline var STUCK = 300;
  // exit codes the runner reads: a known failure (tests/known.json) is reported but not counted
  static inline var EXIT_FAILED = 1;
  static inline var EXIT_KNOWN = 3;

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

      boot();
      var parts = id.split(':');
      if (parts[0] == 'smoke')
        smoke(Std.parseInt(parts[1]), Std.parseInt(parts[2]));
      else if (parts[0] == 'fuzz')
        {
          fuzz(id, parts[1], Std.parseInt(parts[2]), Std.parseInt(parts[3]));
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

// the run ids of the suite asked for; --quick is the cut `cd src && make` runs on every build
  static function plan(): Array<String>
    {
      var quick = has('--quick');
      var suite = strArg('--suite', 'all');
      var seed0 = intArg('--seed', 1);
      var count = intArg('--count', quick ? 5 : 20);
      var steps = intArg('--steps', quick ? 200 : 1000);
      var all = (suite == 'all');
      if (!all &&
          suite != 'smoke' &&
          suite != 'fuzz')
        return null;
      var ids = [];
      if (all ||
          suite == 'smoke')
        ids.push('smoke:' + seed0 + ':' + count);
      if (all ||
          suite == 'fuzz')
        {
          var start = strArg('--start', null);
          var starts = (start != null ? start.split(',') : [ 'new' ].concat(STAGES));
          // the quick cut plays every start point once, the soak each of them on every seed
          for (st in starts)
            for (i in 0...(quick ? 1 : count))
              ids.push('fuzz:' + st + ':' + (seed0 + i) + ':' + steps);
        }
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
      var text = failures.join('\n  ');
      var knownAs = knownMatch(text);
      log((knownAs != null ? 'known ' : '') + id + ': ' + text);
      exit(knownAs != null ? EXIT_KNOWN : EXIT_FAILED);
    }

// where a failure is filed, when tests/known.json has an entry whose `match` it contains
  static function knownMatch(text: String): String
    {
      // the runner's parse of tests/known.json: untyped JSON off disk, [{ match, todo }]
      var list: Array<Dynamic> = js.Syntax.code("host.known");
      for (k in list)
        if (text.indexOf(k.match) >= 0)
          return k.todo;
      return null;
    }

// build the game object graph the way Main.init does, minus the canvas, the shader warm and the menu
  static function boot()
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
    }

// start a new game on this seed, as ui.NewGame.newGame does
  public static function newGame(seed: Int)
    {
      reseed(seed);
      // Game.restartPre resets only the region and cult id counters; the rest carry on from the
      // previous game, which a second New Game in one session shrugs off but which would make a
      // seed's game depend on the seeds run before it in this process
      AreaGame._maxID = 0;
      ai.AIData._maxID = 0;
      objects.AreaObject._maxID = 0;
      cult.Mission._maxID = 0;
      cult.base.CultBaseOrgan._maxID = 0;
      cult.base.RivalBaseOrgan._maxID = 0;
      region.RegionObject._maxID = 1;
      @:privateAccess scenario.NPC._maxID = 0;
      // Game.init logs its first lines BEFORE it zeroes turns, so they carry the last game's turn
      // (TODO.md); zeroed here so a seed's game does not depend on the one before it
      game.turns = 0;
      // the stage presets switch these off and only the Game constructor switches them back on
      game.importantMessagesEnabled = true;
      // the profile outlives a game by design (unlocked pedia articles and the like), so a fresh one
      // stands in for a fresh install — what a process sees on its first game
      game.profile = new Profile(game);
      // the path and repeat stepping is throttled by the wall clock; the tests step it themselves
      game.config.repeatDelay = 0;
      // > 0 answers every Difficulty window on its own (ui.UI.closeWindow)
      game.config.difficulty = 1 + seed % 3;
      game.scenarioStringID = 'alien';
      game.isStarted = true;
      game.ui.closeWindow();
      game.restart();
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
      var res = play(start, seed, steps, stop);
      if (stop >= 0)
        {
          log('    save: ' + failSave(id));
          exit(0);
          return;
        }
      if (res.failure == null)
        {
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

// one bot game from a start point: the step it broke at and why, or no failure. stopAt >= 0
// stops cleanly before that step, which is how a failure is replayed up to the moment before
  static function play(start: String, seed: Int, steps: Int, stopAt: Int): {
      failure: String,
      step: Int,
      trail: Array<String>,
    }
    {
      var alerts: Array<String> = js.Syntax.code("host.alerts");
      var bot: Bot = null;
      var step = -1;
      var failure: String = null;
      try
        {
          newGame(seed);
          if (start != 'new')
            game.console.run(start);
          bot = new Bot(game, seed);
          var lastTurn = game.turns;
          var still = 0;
          step = 0;
          while (step < steps &&
              step != stopAt)
            {
              var n = alerts.length;
              if (!bot.step())
                break;
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
      return {
        failure: failure,
        step: step,
        trail: (bot != null ? bot.trail : []),
      };
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

// reseed the runner's Math.random
  static inline function reseed(seed: Int)
    js.Syntax.code("globalThis.__seed({0})", seed);

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
