// console learn command helper
package console;

import const.*;
import game.Game;

class Learn
{
  public var console: Console;
  var game: Game;

// sets up learn command helper
  public function new(c: Console)
    {
      console = c;
      game = console.game;
    }

// routes a learn command to its sub-handler; returns false if not a learn command
  public function run(cmd: String): Bool
    {
      var arr = cmd.split(' ');
      if (arr[0] != 'learn')
        return false;
      var sub = (arr.length > 1 ? arr[1] : '');
      switch (sub)
        {
          case 'clues':
            clues();
          case 'event':
            event(arr);
          case 'improvements':
            improvements(arr);
          case 'region':
            region();
          case 'timeline':
            timeline();
          case '':
            log('Usage: learn [clues|event [index]|improvements [level]|region|timeline]');
          default:
            log('Unknown learn command: ' + sub + '.');
        }
      return true;
    }

// learns 5 random clues
  function clues()
    {
      game.goals.receive(GOAL_LEARN_CLUE);
      game.goals.complete(GOAL_LEARN_CLUE);
      for (i in 0...5)
        game.timeline.learnClues(game.timeline.getRandomEvent(), true);
    }

// learns everything about an event: learn event [index]
  function event(arr: Array<String>)
    {
      if (arr.length < 3)
        {
          log('Usage: learn event [event index]');
          return;
        }
      var idx = Std.parseInt(arr[2]);
      var event = game.timeline.getEventByIndex(idx);
      if (event == null)
        {
          log('Event [' + idx + '] not found in the timeline.');
          return;
        }
      while (!event.notesKnown())
        event.learnNote();
      event.learnLocation();
    }

// learns all improvements at a level: learn improvements [level]
  function improvements(arr: Array<String>)
    {
      var level = 3;
      if (arr.length > 2)
        level = Std.parseInt(arr[2]);
      for (imp in EvolutionConst.improvements)
        game.player.evolutionManager.addImprov(imp.id, level);
      log('All improvements learned.');
      game.player.evolutionManager.state = 2;
    }

// opens the whole region map
  function region()
    {
      for (a in game.region)
        a.isKnown = true;
      if (game.location == LOCATION_REGION)
        game.scene.region.update();
      log('Region map opened.');
    }

// opens the whole timeline (events, notes, npcs)
  function timeline()
    {
      game.log('Timeline opened.');
      for (e in game.timeline)
        {
          e.locationKnown = true;
          for (n in e.notes)
            n.isKnown = true;
          for (npc in e.npc)
            {
              npc.nameKnown = true;
              npc.jobKnown = true;
              npc.areaKnown = true;
              npc.statusKnown = true;
            }
        }
      game.player.vars.npcEnabled = true;
      game.player.vars.searchEnabled = true;
      game.timeline.update(); // update event numbering
    }

// log shortcut
  inline function log(s: String)
    {
      console.log(s);
    }
}
