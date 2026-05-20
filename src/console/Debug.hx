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
#if mydebug
          case 'alert':
            game.log('This is a test alert message.', COLOR_ALERT);
          case 'demo':
            finishDemo();
          case 'leave':
            leaveArea();
          case 'throw':
            throw 'test exception';
#end
          case '':
            log('Usage: debug [renderstats|ai|sound|lights|alert|demo|leave|throw]');
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
        'emptyScreenCells: ' + game.scene.area.emptyScreenCells +
        ' / AREA_AI_CELLS: ' + WorldConst.AREA_AI_CELLS + ', ' +
        game.area.getMaxAICoef() + ')]'
      );
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

#if mydebug
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

// leaves the current area back to the region
  function leaveArea()
    {
      if (game.location != LOCATION_AREA)
        game.log('Not in area.');
      else game.setLocation(LOCATION_REGION);
    }
#end

// log shortcut
  inline function log(s: String)
    {
      console.log(s);
    }
}
