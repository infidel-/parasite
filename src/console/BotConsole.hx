// console bot command: the headless tests' bot (test.Bot) playing the live game, to watch what it
// does and to step through the state a test failure saved (tests/README.md)
package console;

import game.Game;
import test.Bot;

class BotConsole
{
  public var console: Console;
  var game: Game;
  var bot: Bot;
  var timer: haxe.Timer; // the running `bot run`, or null
  var left: Int; // steps that run still has to take

// sets up bot command helper
  public function new(c: Console)
    {
      console = c;
      game = console.game;
    }

// routes a bot command; arr[0] is 'bot'
  public function run(arr: Array<String>)
    {
      var sub = (arr.length > 1 ? arr[1] : '');
      switch (sub)
        {
          // play N steps, one per two turn animations, so each one can be watched
          case 'run':
            var steps = (arr.length > 2 ? Std.parseInt(arr[2]) : null);
            var policy = (arr.length > 3 ? arr[3] : 'random');
            if (policy != 'random' &&
                policy != 'goal')
              {
                log('Unknown bot policy: ' + policy + '. Use random|goal.');
                return;
              }
            stop(null);
            bot = new Bot(game, Std.random(0x7FFFFFFF), policy);
            left = (steps != null ? steps : 200);
            timer = new haxe.Timer(Std.int(render.RenderConfig.BASE_MS * 2 / render.RenderConfig.ANIM_SPEED));
            timer.run = tick;
            log('Bot: ' + policy + ' play for ' + left + ' steps (bot stop to stop).');
          case 'step':
            if (bot == null)
              bot = new Bot(game, Std.random(0x7FFFFFFF), 'random');
            left = 1;
            tick();
          case 'stop':
            stop('Bot stopped.');
          case 'check':
            var broken = new Bot(game, 1, 'random').check();
            log(broken.length == 0 ? 'Bot check: every invariant holds.' : 'Bot check: ' + broken.join('; '));
          // seed Math.random (until a reload) and start a new game: the seed's world is the headless
          // run's, but its play is not, since the renderer draws from the same stream between turns
          case 'seed':
            var seed = (arr.length > 2 ? Std.parseInt(arr[2]) : null);
            if (seed == null)
              {
                log('Usage: bot seed [n]');
                return;
              }
            stop(null);
            Bot.seed(game, seed);
            game.scenarioStringID = 'alien';
            game.isStarted = true;
            game.ui.closeWindow();
            game.restart();
            log('Bot: new game on seed ' + seed + '.');
          default:
            log('Usage: bot run [steps] [random|goal], bot step, bot stop, bot check, bot seed [n].');
        }
    }

// take one step of a run, and stop it on the first broken invariant, a throw or the game's end
  function tick()
    {
      if (left <= 0 ||
          game.state == GAMESTATE_FINISH)
        {
          stop('Bot: done.');
          return;
        }
      left--;
      try
        {
          if (!bot.step())
            {
              stop('Bot: nothing left to do.');
              return;
            }
        }
      catch (e: haxe.Exception)
        {
          stop('Bot: threw after ' + bot.trail[bot.trail.length - 1] + ': ' + e.message);
          return;
        }
      log('Bot: ' + bot.trail[bot.trail.length - 1]);
      var broken = bot.check();
      if (broken.length > 0)
        stop('Bot: ' + broken.join('; '));
    }

// end a run; a null message ends it quietly
  function stop(msg: String)
    {
      if (timer != null)
        timer.stop();
      timer = null;
      if (msg != null)
        log(msg);
    }

  inline function log(s: String)
    console.log(s);
}
