// event timeline GUI window

package ui;

import game.Game;

class Timeline extends Text
{
  public function new(g: Game)
    { super(g); }


// update text
  override function update()
    {
      var buf = new StringBuf();

      buf.add('Event timeline\n===\n\n');

      for (event in game.timeline)
        {
          // hidden event
          if (event.isHidden)
            continue;

          // check if anything is known at all
          var npcSomethingKnown = event.npcSomethingKnown();
          var notesSomethingKnown = event.notesSomethingKnown();

          // nothing is known, skip that event
          if (!event.locationKnown && !npcSomethingKnown && !notesSomethingKnown)
            continue;

          // first line (events are always numbered relative to known ones)
          buf.add('Event ' + event.num);
#if mydebug
          buf.add(' [index: ' + event.index + ']');
#end
          if (event.location != null)
            {
              buf.add(': ');
              if (event.locationKnown)
                {
                  if (event.location.hasName)
                    buf.add(event.location.name + ' ');
                  buf.add('at (' + event.location.area.x + ',' +
                    event.location.area.y + ')');
                }
              else buf.add('at (?,?)');
            }
          buf.add('\n');

          // event notes
          for (n in event.notes)
            if (n.isKnown)
              buf.add(' + ' + n.text + '\n');
            else if (n.clues > 0)
              buf.add(' - ? [' + n.clues + '/4]\n');

          // event participants
          buf.add('Participants:\n');
          var numDeceasedAndKnown = 0;
          var numAliveAndMemoryKnown = 0;
          if (npcSomethingKnown)
            for (npc in event.npc)
              {
                // nothing is known
                if (!npc.nameKnown && !npc.jobKnown && !npc.areaKnown &&
                    !npc.statusKnown)
                  continue;

                // count number or dead and known dead
                if (npc.isDead && npc.statusKnown)
                  {
                    numDeceasedAndKnown++;
                    continue;
                  }

                // count number of alive and scanned npcs
                if (!npc.isDead && npc.memoryKnown)
                  {
                    numAliveAndMemoryKnown++;
                    continue;
                  }

                // npc fully known
                if (npc.nameKnown && npc.jobKnown && npc.areaKnown &&
                    npc.statusKnown)
                  buf.add(' + ');
                else buf.add(' - ');
                buf.add((npc.nameKnown ? npc.name : '?') + ' ');
                buf.add('(' + (npc.jobKnown ? npc.job : '?') + ') ');
                if (npc.areaKnown)
                  buf.add('at (' + npc.area.x + ',' + npc.area.y + ') ');
                else buf.add('at (?,?) ');
                buf.add(npc.jobKnown ? '[photo] ' : '[no photo] ');
                if (!npc.statusKnown)
                  buf.add('status: unknown');
                buf.add('\n');
              }

          // nothing known about any npcs
          if (!npcSomethingKnown && event.npc.length > 0)
            buf.add('  unknown\n');

          // no npcs
          else if (event.npc.length == 0)
            buf.add('  none\n');

          if (numAliveAndMemoryKnown > 0)
            buf.add(" ... +" + numAliveAndMemoryKnown + " persons probed ...\n");

          if (numDeceasedAndKnown > 0)
            buf.add(" ... +" + numDeceasedAndKnown + " persons deceased ...\n");

          buf.add('\n');
        }

      setParams(buf.toString());
    }
}