// scenario event

package scenario;

import game.Game;
import scenario.Scenario;

class Event extends _SaveObject
{
  static var _ignoredFields = [ 'location', ];
  public var game: Game;
  public var info(get, null): EventInfo; // event info link
  public var num: Int; // event number (temp var for text messages)
  public var isHidden: Bool; // event hidden?
  public var id: String; // event id
  public var index: Int; // event index in array
  public var name: String; // event name
  public var locationID: String; // location id
  public var location(get, null): Location; // event location link (can be null)
  public var locationKnown: Bool; // event location known?
  public var notes: Array<EventNote>; // event notes
  public var npc: Array<NPC>; // event npcs

  public function new(g: Game, vid: String, idx: Int)
    {
      game = g;
      id = vid;
      index = idx;
      init();
      initPost(false);
    }

// init object before loading/post creation
  public function init()
    {
      name = 'unnamed event';
      info = null;
      locationID = null;
      location = null;
      locationKnown = false;
      notes = [];
      npc = [];
    }

// called after load or creation
  public function initPost(onLoad: Bool)
    {
    }

// get npc by id
  public function getNPC(id: Int): NPC
    {
      for (n in npc)
        if (n.id == id)
          return n;
      return null;
    }

// learn a note clue
  public function learnClue(): Bool
    {
      // all notes already known
      if (notesKnown())
        return false;

      // get first unknown note
      var note = null;
      for (n in notes)
        if (!n.isKnown)
          {
            n.clues++;
            if (n.clues >= 4)
              {
                n.isKnown = true;
                note = n;
              }

            break;
          }

      game.timeline.update(); // update event numbering

      game.player.log('You have gained a clue for event ' + num + '.',
        COLOR_TIMELINE);
      if (note != null)
        {
          game.player.log('<i>' + note.text + '</i>', COLOR_TIMELINE);

          // event hook
          var idx = -1;
          for (i in 0...notes.length)
            if (notes[i] == note)
              idx = i;
//          var idx = notes.indexOf(note);
          if (info.onLearnNote != null)
            info.onLearnNote(game, idx);
        }

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

      // if there are any npc whose name/job is not known
      // learn that first since location does not allow computer NPC research
      // resulting in a potential dead end
      for (n in npc)
        if (!n.nameKnown || !n.jobKnown)
          {
            if (!n.nameKnown && !n.jobKnown)
              type = (Std.random(2) == 0 ? 'name' : 'job');
            else if (!n.nameKnown)
              type = 'name';
            else if (!n.jobKnown)
              type = 'job';

            break;
          }

      // loop through all npcs finding one has that bit unknown
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

            game.timeline.update(); // update event numbering
            game.player.log('You have gained a clue about an event ' +
              num + ' participant.', COLOR_TIMELINE);

            // goal completed: learn about any npc
            game.goals.complete(GOAL_LEARN_NPC);

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

      var note = null;
      for (n in notes)
        if (!n.isKnown)
          {
            n.isKnown = true;
            note = n;

            break;
          }

      game.timeline.update(); // update event numbering
      game.player.log('You have gained a major clue for event ' + num + '.',
        COLOR_TIMELINE);
      game.player.log(Const.narrative(note.text), COLOR_TIMELINE);

      // event hook
      var idx = -1;
      for (i in 0...notes.length)
        if (notes[i] == note)
          idx = i;
//      var idx = notes.indexOf(note);
      if (info.onLearnNote != null)
        info.onLearnNote(game, idx);

      return true;
    }


// learn location
  public function learnLocation(): Bool
    {
      if (location == null || locationKnown)
        return false;

      locationKnown = true;

      game.timeline.update(); // update event numbering
      game.player.log('You have gained the location for event ' + num + '.',
        COLOR_TIMELINE);

      // event hook
      if (info.onLearnLocation != null)
        info.onLearnLocation(game);

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
        if (!n.fullyKnown())
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
              !n.statusKnown)
            continue;

          return true; // something is known about some npc
        }

      return false;
    }


// can research npcs of this event (have some partially known)
  public function npcCanResearch(): Bool
    {
      for (n in npc)
        {
          // nothing is known - cannot research
          if (!n.nameKnown && !n.jobKnown && !n.areaKnown &&
              !n.statusKnown)
            continue;

          // everything is known - cannot research
          else if (n.fullyKnown())
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

  function get_location(): Location
    {
      if (locationID == null)
        return null;
      else return game.timeline.getLocation(locationID);
    }

  function get_info(): EventInfo
    {
      return game.timeline.scenario.flow.get(id);
    }

  public function toString(): String
    {
      return 'event ' + index + ', num: ' + num + ', id: ' + id + ', ' +
        name + '\n' +
        '  locationKnown: ' + locationKnown + '\n' +
        '  location: { ' + location + ' }\n' +
        '  notes: ' + notes + '\n' +
        '  NPCs: ' + npc + '\n';
    }
}


typedef EventNote = {
  var text: String; // note text
  var isKnown: Bool; // note known?
  var clues: Int; // amount of note clues known (0...4)
}
