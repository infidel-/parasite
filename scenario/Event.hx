// scenario event

package scenario;

import game.Game;

class Event
{
  public var game: Game;

  public var num: Int; // event number (temp var for text messages)

  public var isHidden: Bool; // event hidden?
  public var id: String; // event id
  public var name: String; // event name
  public var notes: Array<EventNote>; // event notes 
  public var location: Location; // event location link (can be null)
  public var locationKnown: Bool; // event location known?
  public var npc: Array<NPC>; // event npcs 

  public function new(g: Game, vid: String)
    {
      game = g;
      id = vid;
      name = 'unnamed event';
      notes = [];
      npc = []; 
    }


// learn a note clue
  public function learnClue(): Bool
    {
      // all notes already known
      if (notesKnown())
        return false;

      for (n in notes)
        if (!n.isKnown)
          {
            n.clues++;
            if (n.clues >= 4)
              n.isKnown = true;

            break;
          }

      game.timeline.update(); // update event numbering

      game.player.log('You have gained a clue for event ' + num + '.',
        COLOR_TIMELINE);

      return true;
    }


// learn an npc clue
  public function learnNPC(): Bool
    {
      // pick a random thing about npc
      var rnd2 = Std.random(100);
      var type = '';
      if (rnd2 < 33)
        type = 'name';
      else if (rnd2 < 67)
        type = 'job';
      else type = 'area';

      // loop through all npcs finding one has that bit unknown
      var ok = true;
      for (n in npc)
        if ((type == 'name' && !n.nameKnown) ||
            (type == 'job' && !n.jobKnown) ||
            (type == 'area' && !n.areaKnown))
          {
            if (type == 'name')
              n.nameKnown = true;
            else if (type == 'job')
              n.jobKnown = true;
            else if (type == 'area')
              n.areaKnown = true;

            game.player.log('You have gained a clue about an event ' +
              num + ' participant.', COLOR_TIMELINE);

            // goal completed: learn about any npc
            game.player.goals.complete(GOAL_LEARN_NPC);

            return true;
          }

      return false;
    }


// learn a full note
  public function learnNote(): Bool
    {
      // all notes already known
      if (notesKnown())
        return false;

      for (n in notes)
        if (!n.isKnown)
          {
            n.isKnown = true;

            break;
          }

      game.timeline.update(); // update event numbering

      game.player.log('You have gained a major clue for event ' + num + '.',
        COLOR_TIMELINE);

      return true;
    }


// names or jobs of all npcs are known?
  public function npcNamesOrJobsKnown(): Bool
    {
      for (n in npc)
        if (!n.nameKnown && !n.jobKnown)
          return false;

      return true;
    }


// all npcs fully known 
  public function npcFullyKnown(): Bool
    {
      for (n in npc)
        if (!n.nameKnown || !n.jobKnown || !n.areaKnown || !n.isDeadKnown)
          return false;

      return true; 
    }


// something is known about npc of this event?
  public function npcSomethingKnown(): Bool
    {
      for (n in npc)
        {
          // nothing is known
          if (!n.nameKnown && !n.jobKnown && !n.areaKnown && 
              !n.isDeadKnown)
            continue;

          return true; // something is known about some npc
        }

      return false;
    }


// something is known about some note?
  public function notesSomethingKnown(): Bool
    {
      for (n in notes)
        if (n.isKnown || n.clues > 0)
          return true; // something is known about some note

      return false;
    }


// all notes known?
  public function notesKnown(): Bool
    {
      for (n in notes)
        if (!n.isKnown)
          return false;

      return true;
    }


  public function toString(): String
    {
      return id + ' ' + name + '\n' + notes + '\n' + npc;
    }
}


typedef EventNote = {
  var text: String; // note text
  var isKnown: Bool; // note known?
  var clues: Int; // amount of note clues known (0...4)
}
