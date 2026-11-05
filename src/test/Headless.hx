// headless game runner: the real game logic under node with no renderer, for automated tests
//
// the entry point of ../bin/test.js, driven by tools/test.mjs, which stubs the leaf browser APIs
// (THREE, DOM, WebAudio) and supplies a seeded Math.random and an in-memory window.host. Everything
// above those leaves is the shipped code — Game, UI, GameScene, render.View — so a test here plays
// the game the player plays, through the same entry points the keyboard and the windows use.
//
// one process runs many games back to back: each seed is a fresh restart() on the same Game, the
// way the menu's New Game does it. See tests/README.md.

package test;

import game.AreaGame;
import game.Game;

class Headless
{
  static var argv: Array<String>;
  static var game: Game;
  static var failures: Array<String> = [];

  static function main()
    {
      argv = js.Syntax.code("process.argv");
      // --quick is the cut `cd src && make` runs on every build; the default is the full soak
      var quick = has('--quick');
      var suite = strArg('--suite', 'all');
      var seed0 = intArg('--seed', 1);
      var count = intArg('--count', quick ? 5 : 20);
      // the game's own traces (one per area generated, per profile miss) bury the report
      if (!has('--trace'))
        haxe.Log.trace = function(v, ?infos) {};
      boot();
      if (suite == 'smoke' ||
          suite == 'all')
        smoke(seed0, count);
      else
        {
          log('[test] unknown --suite: ' + suite);
          exit(2);
          return;
        }

      if (failures.length == 0)
        {
          log('[test] ' + suite + ' OK');
          exit(0);
          return;
        }
      log('[test] ' + suite + ' FAILED: ' + failures.length);
      for (f in failures)
        log('  ' + f);
      exit(1);
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

// a new game on this seed, ten waits, and the save it would write
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

  static inline function log(s: String)
    js.Syntax.code("console.log({0})", s);

// exit now: the stubbed timers the UI arms (toasts, fades) would otherwise hold node open
  static inline function exit(code: Int)
    js.Syntax.code("process.exit({0})", code);
}
