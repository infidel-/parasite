// console debug command helper
package console;

import const.*;
import game.Game;

class Debug
{
  public var console: Console;
  var game: Game;

// sets up debug command helper
  public function new(c: Console)
    {
      console = c;
      game = console.game;
    }

// routes a debug command to its sub-handler; returns false if not a debug command
// NOTE: when adding/changing a debug sub-command, update its hint in
// ConsoleCompletion.hx (the debugSubs list) so autocomplete stays in sync
  public function run(cmd: String): Bool
    {
      var arr = cmd.split(' ');
      if (arr[0] != 'debug')
        return false;
      var sub = (arr.length > 1 ? arr[1] : '');
      switch (sub)
        {
          case 'renderstats':
            renderStats();
          case 'ai':
            aiInfo();
          case 'sound':
            toggleSound();
          case 'lights':
            toggleLights();
          case 'colors':
            listColors();
          case 'difficulty' if (Const.isDebug):
            openDifficulty(arr[2]);
          case 'alert' if (Const.isDebug):
            game.log('This is a test alert message.', COLOR_ALERT);
          case 'demo' if (Const.isDebug):
            finishDemo();
          case 'leave' if (Const.isDebug):
            leaveArea();
          case 'throw' if (Const.isDebug):
            throw 'test exception';
          case '':
            log('Usage: debug [renderstats|ai|sound|lights|colors|difficulty|alert|demo|leave|throw]');
          default:
            log('Unknown debug command: ' + sub + '.');
        }
      return true;
    }

// writes render profile to the browser console
  function renderStats()
    {
      game.scene.logRenderStatsToConsole();
      game.log('Render profile written to browser console.', COLOR_DEBUG);
    }

// shows ai view/hear info for the current area
  function aiInfo()
    {
      log(
        'Window resolution: ' +
        game.scene.canvas.width + 'x' + game.scene.canvas.height +
        ', scale: ' + (game.config.mapScale * 100) +
        '%, tile resolution: ' +
        Std.int(game.scene.canvas.width / Const.TILE_SIZE) + 'x' +
        Std.int(game.scene.canvas.height / Const.TILE_SIZE) +
        ', AI view distance: ' + ai.AI.VIEW_DISTANCE +
        ', AI hear distance: ' + ai.AI.HEAR_DISTANCE +
        '<br>Current area, max AI: ' + game.area.getMaxAI() +
        ' = [common AI: ' + game.area.info.commonAI +
        ' * pow(' +
        'spawnCells: ' + game.area.spawnCells +
        ' / AREA_AI_CELLS: ' + WorldConst.AREA_AI_CELLS + ', ' +
        game.area.getMaxAICoef() + ')]' +
        '<br>Spawn region: ' + spawnRectText() +
        ' (2D emptyScreenCells: ' + game.scene.area.emptyScreenCells + ')'
      );
    }

// describe the AI spawn region: its size and which viewport it came from (the 3D camera
// footprint in city areas, the 2D screen rect everywhere else)
  function spawnRectText(): String
    {
      var r = game.area.getSpawnRect();
      return (r.x2 - r.x1) + 'x' + (r.y2 - r.y1) +
        (game.area.isCity() ? ' (3D camera footprint)' : ' (2D screen rect)');
    }

// toggles debug sound info
  function toggleSound()
    {
      game.player.vars.debugSoundEnabled = !game.player.vars.debugSoundEnabled;
      game.debug('Sound debug toggled.');
    }

// toggles debug markers for area light sources
  function toggleLights()
    {
      game.player.vars.debugLightsEnabled = !game.player.vars.debugLightsEnabled;
      var state = (game.player.vars.debugLightsEnabled ? 'on' : 'off');
      game.debug('Light marker debug toggled: ' + state + '.');
    }

// finishes the demo with a lose result
  function finishDemo()
    {
      game.message({
        text: 'Thank you for playing the demo! You can restart the game now and play it to this point again but to progress further you will need to buy the full game.'
      });
      game.ui.event({
        type: UIEVENT_FINISH,
        state: null,
        obj: {
          result: 'lose',
          condition: 'demo',
        }
      });
    }

// dumps base + log text colors to game log, one colored line per CSS var
  function listColors()
    {
      var entries = [
        [ '--text-fg-color', 'default foreground text' ],
        [ '--text-color-white', 'plain white text' ],
        [ '--text-color-yellow', 'highlighted yellow text' ],
        [ '--text-color-red', 'red text / errors' ],
        [ '--text-color-gray', 'gray / inactive / muted text' ],
        [ '--text-color-repeat', 'repeated log message counter' ],
        [ '--text-color-timeline', 'timeline events' ],
        [ '--text-color-goal', 'goals' ],
        [ '--text-color-pedia', 'pedia entries' ],
        [ '--text-color-symbiosis', 'symbiosis / affinity / consent' ],
        [ '--text-color-cultist', 'cultist references' ],
        [ '--text-color-debug', 'debug messages' ],
        [ '--text-color-alert', 'alerts / warnings' ],
        [ '--text-color-evolution', 'evolution / mutations' ],
        [ '--text-color-organ', 'organs' ],
        [ '--text-color-hint', 'gameplay hints' ],
        [ '--text-color-message', 'story messages' ],
        [ '--text-color-cult', 'cult references' ],
        [ '--text-color-energy', 'energy resource' ],
        [ '--text-color-income', 'income / earnings' ],
        [ '--text-color-money', 'money resource' ],
        [ '--text-color-trait', 'host traits' ],
      ];
      var buf = new StringBuf();
      for (e in entries)
        {
          buf.add("<span style='color:var(" + e[0] + ")'>");
          buf.add(e[0]);
          buf.add(' - ');
          buf.add(e[1]);
          buf.add('</span><br/>');
        }
      game.log(buf.toString());
    }

// opens the difficulty selection window for a setting key (default survival);
// 'all' queues every difficulty window one by one
  function openDifficulty(key: String)
    {
      if (key == null)
        key = 'survival';
      if (key == 'all')
        {
          // queue each difficulty window, with a test message between them
          for (k in ui.Difficulty.choices.keys())
            {
              game.ui.event({
                type: UIEVENT_STATE,
                state: UISTATE_DIFFICULTY,
                obj: k
              });
              game.message({ text: 'Test message after difficulty: ' + k });
            }
          return;
        }
      if (!ui.Difficulty.choices.exists(key))
        {
          log('Usage: debug difficulty [all|survival|group|evolution|timeline|save|chat]');
          return;
        }
      game.ui.event({
        type: UIEVENT_STATE,
        state: UISTATE_DIFFICULTY,
        obj: key
      });
    }

// leaves the current area back to the region
  function leaveArea()
    {
      if (game.location != LOCATION_AREA)
        game.log('Not in area.');
      else game.setLocation(LOCATION_REGION);
    }

// log shortcut
  inline function log(s: String)
    {
      console.log(s);
    }
}
