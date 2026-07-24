// console learn command helper
package console;

import const.*;
import game.Game;

class Learn
{
  public var console: Console;
  var game: Game;
  var giveEvolution: GiveEvolution; // reused for improvement name matching

// sets up learn command helper
  public function new(c: Console)
    {
      console = c;
      game = console.game;
      giveEvolution = new GiveEvolution(c);
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
          case 'improvement':
            improvement(arr);
          case 'npcs':
            npcs(arr);
          case 'region':
            region();
          case 'timeline':
            timeline();
          case '':
            log('Usage: learn [clues|event [index]|improvement <name> <level>|npcs [count]|region|timeline]');
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

// learns an improvement at a level: learn improvement <name> <level> (name=all learns all)
  function improvement(arr: Array<String>)
    {
      if (arr.length < 3)
        {
          log('Usage: learn improvement <name|all> <level>');
          return;
        }
      var name = arr[2];
      var level = (arr.length > 3 ? Std.parseInt(arr[3]) : -1);

      // learn every improvement (level clamped per improvement)
      if (name == 'all')
        {
          for (imp in EvolutionConst.improvements)
            {
              var lv = level;
              if (lv < 0 || lv > imp.maxLevel)
                lv = imp.maxLevel;
              game.player.evolutionManager.addImprov(imp.id, lv);
            }
          log('All improvements learned.');
          game.player.evolutionManager.state = 2;
          return;
        }

      // single improvement by name
      var match = giveEvolution.selectMatch('improvement', name, giveEvolution.buildEntries());
      if (match == null)
        return;
      var info = null;
      try { info = EvolutionConst.getInfo(match.value); }
      catch (e: Dynamic) { info = null; }
      if (info == null)
        {
          log('Improvement info not found.');
          return;
        }
      var lv = level;
      if (lv < 0 || lv > info.maxLevel)
        lv = info.maxLevel;
      game.player.evolutionManager.addImprov(match.value, lv);
      log('Learned ' + info.name + ' ' + lv);
    }

// fully learns some timeline npcs: learn npcs [count] (default 5)
  function npcs(arr: Array<String>)
    {
      var count = (arr.length > 2 ? Std.parseInt(arr[2]) : 5);
      if (count == null || count < 1)
        count = 5;

      // gather all timeline npcs
      var all = [];
      for (e in game.timeline)
        for (npc in e.npc)
          if (!npc.fullyKnown())
            all.push(npc);
      if (all.length == 0)
        {
          log('No unknown timeline npcs left.');
          return;
        }

      // fully learn a random subset
      var n = 0;
      while (n < count && all.length > 0)
        {
          var npc = all.splice(Std.random(all.length), 1)[0];
          npc.nameKnown = true;
          npc.jobKnown = true;
          npc.areaKnown = true;
          npc.statusKnown = true;
          n++;
        }
      game.player.vars.npcEnabled = true;
      game.timeline.update(); // update event numbering
      log('Fully learned ' + n + ' timeline npc(s).');
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
