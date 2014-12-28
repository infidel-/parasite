// event timeline GUI window

package entities;

class TimelineWindow extends TextWindow
{
  public function new(g: Game)
    {
      super(g);
    }


// update window text
  override function getText()
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
          if (npcSomethingKnown)
            for (npc in event.npc)
              {
                // nothing is known
                if (!npc.nameKnown && !npc.jobKnown && !npc.areaKnown && 
                    !npc.isDeadKnown)
                  continue;

                // count number or dead and known dead
                if (npc.isDead && npc.isDeadKnown)
                  {
                    numDeceasedAndKnown++;
                    continue;
                  }

                // npc fully known
                if (npc.nameKnown && npc.jobKnown && npc.areaKnown &&
                    npc.isDeadKnown)
                  buf.add(' + ');
                else buf.add(' - ');
                buf.add((npc.nameKnown ? npc.name : '?') + ' ');
                buf.add('(' + (npc.jobKnown ? npc.job : '?') + ') ');
                if (npc.areaKnown)
                  buf.add('at (' + npc.area.x + ',' + npc.area.y + ') ');
                else buf.add('at (?,?) ');
                buf.add(npc.jobKnown ? '[photo] ' : '[no photo] ');
//                if (npc.isDead && npc.isDeadKnown)
//                  buf.add('[deceased]');
                buf.add('\n');
              }

          // nothing known about any npcs
          else buf.add('  unknown');

          if (numDeceasedAndKnown > 0)
            buf.add(" ... +" + numDeceasedAndKnown + " persons deceased ...\n");

          buf.add('\n');
        }

      return buf.toString();
    }
}
