// console perf command: toggle the profiler overlays (turn timing / 3D render passes)
package console;

import game.Game;

class Perf
{
  public var console: Console;
  var game: Game;

// sets up perf command helper
  public function new(c: Console)
    {
      console = c;
      game = console.game;
    }

// routes a perf command to its toggle; returns false if not a perf command
  public function run(cmd: String): Bool
    {
      var arr = cmd.split(' ');
      if (arr[0] != 'perf')
        return false;
      var sub = (arr.length > 1 ? arr[1] : '');
      switch (sub)
        {
          // turn profiler: logs slow (>6ms) game-turn phase timings + growth counts
          case 'turn':
            Game.DEBUG_TURN = !Game.DEBUG_TURN;
            log('Turn profiler ' + onOff(Game.DEBUG_TURN) +
              ' (logs turn phases >6ms to the browser console).');
          // street render profiler: logs 3D actor/decal/blood pass timings per frame
          case 'street':
            render.Actors.DEBUG_PERF = !render.Actors.DEBUG_PERF;
            log('Street render profiler ' + onOff(render.Actors.DEBUG_PERF) +
              ' (logs 3D pass timings to the browser console).');
          // wall-hole tracer: logs each bullet-hole placement decision (cell/face/ray/build)
          case 'hole':
            render.StreetView.DEBUG_HOLES = !render.StreetView.DEBUG_HOLES;
            log('Wall-hole trace ' + onOff(render.StreetView.DEBUG_HOLES) +
              ' (logs each wall bullet-hole placement to the browser console).');
          case '':
            log('Usage: perf [turn|street|hole] - toggle profiler. ' +
              'turn=' + onOff(Game.DEBUG_TURN) +
              ', street=' + onOff(render.Actors.DEBUG_PERF) +
              ', hole=' + onOff(render.StreetView.DEBUG_HOLES) + '.');
          default:
            log('Unknown perf target: ' + sub + '. Use turn|street|hole.');
        }
      return true;
    }

// on/off label for a toggle
  inline function onOff(v: Bool): String
    {
      return (v ? 'ON' : 'OFF');
    }

// log shortcut
  inline function log(s: String)
    {
      console.log(s);
    }
}
