// event timeline

package scenario;

import scenario.Scenario;
import game.Game;
import const.NameConst;

class Timeline extends _SaveObject
{
  static var _ignoredFields = [ '_eventsMap', '_locationsMap',
  ];
  var game: Game;
  public var scenario: Scenario;
  var scenarioID: String;

  public var difficulty: _Difficulty; // difficulty
  var _eventsMap: Map<String, Event>; // events hash map
  var _eventsList: Array<Event>; // ordered events list
  var _locationsList: List<Location>; // ordered locations list
  var _locationsMap: Map<String, Location>; // locations map
  var _names: Map<String, String>; // fully parsed from templates names
  var _variables: Map<String, Dynamic>; // timeline variables map

  public function new(g: Game)
    {
      game = g;
      init();
    }

// init object before loading/post creation
  public function init()
    {
      scenarioID = null;
      difficulty = UNSET;
      _eventsMap = new Map();
      _eventsList = [];
      _locationsList = new List();
      _locationsMap = new Map();
      _variables = new Map();
      _names = new Map();
    }

// called after load or creation (manually)
  public function loadPost()
    {
      var scenarioClass = Type.resolveClass(scenarioID);
      if (scenarioClass == null)
        throw 'Could not resolve class ' + scenarioID;
      scenario = Type.createInstance(scenarioClass, []);
      // NOTE: need locations before events
      _locationsMap = new Map();
      for (ev in _locationsList)
        _locationsMap[ev.id] = ev;
      _eventsMap = new Map();
      for (ev in _eventsList)
        {
          _eventsMap[ev.id] = ev;
          var loc = ev.location;
          if (loc != null)
            loc.area.events.push(ev);
          for (npc in ev.npc)
            {
              npc.area.npc.add(npc);
              npc.event = ev;
            }
        }
    }

  public function iterator()
    {
      return _eventsList.iterator();
    }

// get clues according to difficulty for this event
// NOTE: isPhysical is for readables, adds a full note chance
  public function learnClues(event: Event, isPhysical: Bool): Bool
    {
      var n = 0;
      switch (difficulty)
        {
          case UNSET:
          case EASY:
            n = 1 + Std.random(3);
          case NORMAL:
            n = 1 + Std.random(2);
          case HARD:
            n = 1;
        }

      var ret = false;
      for (i in 0...n)
        if (learnSingleClue(event, isPhysical))
          ret = true;
      return ret;
    }


// learn a single clue for this event
// NOTE: isPhysical is for readables, adds a full note chance
  public function learnSingleClue(event: Event, isPhysical: Bool): Bool
    {
      // we have a chance of gaining clue from other event up or down the timeline
      var e = event;
      if (Std.random(100) < 30)
        {
          var index = event.index;
          var mod = (Std.random(2) == 0 ? 1 : -1);
          mod = -1;

          // move to the start or to the end of array, skipping hidden events
          while (true)
            {
              index += mod;

              // start/end of array
              if (index < 0 || index >= _eventsList.length)
                break;

              // skip hidden event
              if (_eventsList[index].isHidden)
                continue;

              e = _eventsList[index];
              break;
            }
        }

      // if this is the first time, just learn a clue
      var ret = false;
      if (!game.goals.completed(GOAL_LEARN_CLUE))
        {
          ret = e.learnClue();
          // goal completed - event clue learned
          if (ret)
            game.goals.complete(GOAL_LEARN_CLUE);
          return ret;
        }

      // different event, start from its location
      var t = null;
      if (e != event && e.location != null && !e.locationKnown)
        t = 'location';
      else
        {
          // get a list of things that are still not known for this event
          var types = [];
          var weights = [];
          if (!e.notesKnown())
            {
              if (isPhysical)
                {
                  types.push('note');
                  weights.push(5);
                }
              types.push('clue');
              weights.push(30);
            }
          if (e.location != null && !e.locationKnown)
            {
              types.push('location');
              weights.push(20);
            }
          if (!e.npcFullyKnown())
            {
              types.push('npc');
              weights.push(45);
            }

          // find random type according to weights
          var max = 0;
          for (w in weights)
            max += w;
          var rnd = Std.random(max);
          var cnt = 0;
          for (i in 0...weights.length)
            {
              cnt += weights[i];
              if (rnd < cnt)
                {
                  t = types[i];
                  break;
                }
            }
        }

      // learn event location
      if (t == 'location')
        ret = e.learnLocation();
      // learn event clue
      else if (t == 'clue')
        ret = e.learnClue();
      // npc clues
      else if (t == 'npc')
        ret = e.learnNPC();
      // full event note
      else if (t == 'note')
        ret = e.learnNote();

      return ret;
    }


// unlock event timeline
  public function unlock()
    {
      // skip in sandbox mode
      if (game.scenarioStringID == 'sandbox')
        return;
      // give some starting clues to player
      var e = getStartEvent();
      e.locationKnown = true;
      update(); // update event numbering
    }


// update event numbering
  public function update()
    {
      var n = 1;
      for (event in _eventsList)
        if (event.locationKnown || event.npcSomethingKnown() ||
            event.notesSomethingKnown())
          // stored for use in text messages referring to this event
          event.num = (n++);
    }


// parse scenario names
  function parseNames()
    {
      for (key in scenario.names.keys())
        {
          var tmp = scenario.names.get(key);
          var name = tmp[Std.random(tmp.length)];
          name = NameConst.generate(name);

          _names.set(key, name);
        }
    }


// init location from info
  function initLocation(eventID: String, eventInfo: EventInfo,
      info: LocationInfo, event: Event): Location
    {
      if (info == null)
        return null;

      if (info.id == null)
        info.id = eventID;

      // location exists
      var loc = getLocation(info.id);
      if (loc != null)
        {
          // still add event to the list
          loc.area.events.push(event);

          return loc;
        }

      // copy location from previous event
      if (info.sameAs != null)
        {
          var tmp = getEvent(info.sameAs);
          if (tmp.location == null)
            throw '' + info + ': event ' + info.sameAs + ' does not have location.';

          // still add event to the list
          tmp.location.area.events.push(event);

          return tmp.location;
        }

      var location = new Location(game, info.id);
      if (info.name != null)
        {
          location.name = parse(info.name);
          location.hasName = true;
        }

      var infoTypeWasNull = false;
      if (info.type == null)
        {
          var tmp: Array<_AreaType> =
            [ AREA_CITY_LOW, AREA_CITY_MEDIUM, AREA_CITY_HIGH ];
          info.type = tmp[Std.random(tmp.length)];
          infoTypeWasNull = true;
        }

      // find area with this type
      // single region atm
      var region = game.world.get(0);
      var area = null;

      // location is near this event id
      if (info.near != null)
        {
          var tmp = getEvent(info.near);

          // desired type was not set, try to find inhabited area by default
          if (infoTypeWasNull)
            area = region.getRandomAround(tmp.location.area, {
              minRadius: 2,
              maxRadius: 5,
              isInhabited: true,
            });

          // type was set
          else area = region.getRandomAround(tmp.location.area, {
            minRadius: 2,
            maxRadius: 5,
            type: info.type,
          });

          // first iteration did not find a good area, pick random and force
          if (area == null)
            {
              area = region.getRandomAround(tmp.location.area, {
                minRadius: 2,
                maxRadius: 5,
              });
              area.typeID = info.type;
              area.updateType();
            }
        }
      area = region.getRandomWithType(info.type, true);
      if (area == null)
        area = region.spawnArea(info.type, true);

      // init area
      location.areaID = area.id;
      area.events.push(event);
      area.alertness =
        (info.alertness != null ? info.alertness : scenario.defaultAlertness);
      if (location.hasName)
        area.name = location.name;

      _locationsList.add(location);
      _locationsMap.set(location.id, location);
      return location;
    }


// init npc from info
  function initNPC(eventID: String, eventInfo: EventInfo,
      npc: Map<String, Int>, event: Event)
    {
      // count total number
      var total = 0;
      for (n in npc)
        total += n;

      for (typeExt in npc.keys())
        {
          var max = npc.get(typeExt);
          if (max > 3)
            max = Std.int(max / 2) + Std.random(Std.int(max / 2));

          var job = typeExt;
          var type = typeExt;
          if (typeExt.indexOf(':') >= 0)
            {
              job = typeExt.substr(0, typeExt.indexOf(':'));
              type = typeExt.substr(typeExt.indexOf(':') + 1);
            }

          for (i in 0...max)
            {
              var npc = new NPC(game);
              npc.event = event;
              npc.job = job;
              npc.type = type;
              var tmp = game.scene.images.getAI(type, npc.isMale);
              npc.tileAtlasX = tmp.x;
              npc.tileAtlasY = tmp.y;
              var region = game.world.get(0);

              // find proper area for this NPC
              var area = null;
              if (npc.type == 'soldier')
                area = region.getRandomWithType(AREA_MILITARY_BASE, false);
              else if (event.location != null)
                area = region.getRandomAround(event.location.area, {
                  isInhabited: true,
                  minRadius: 1,
                  maxRadius: 5
                });
              else
                {
                  var tmp: Array<_AreaType> =
                    [ AREA_CITY_LOW, AREA_CITY_MEDIUM, AREA_CITY_HIGH ];
                  var type = tmp[Std.random(tmp.length)];
                  area = region.getRandomWithType(type, false);
                }
              npc.areaID = area.id;
              area.npc.add(npc);

              // event coverup kills some npcs
              if (total > 3)
                npc.isDead = (Std.random(100) < 50 ? true : false);

              event.npc.push(npc);
            }
        }
    }


// init a new scenario
  public function create()
    {
      if (game.scenarioStringID == 'alien')
        scenario = new ScenarioAlienCrashLanding();
      else if (game.scenarioStringID == 'sandbox')
        scenario = new ScenarioSandbox();
      scenarioID = untyped Type.getClass(scenario).__name__;
      if (game.scenarioStringID == 'sandbox') // skip init for sandbox
        return;

      // parse names
      parseNames();

      // walk through available events generating a new timeline
      var n = 1;
      var curID = scenario.startEvent;
      var curInfo = scenario.flow.get(scenario.startEvent);
      while (true)
        {
          var event = new Event(game, curID, _eventsList.length);
          event.num = n++;
          event.name = curInfo.name;
          event.isHidden = (curInfo.isHidden == true);
          _eventsMap.set(curID, event);
          _eventsList.push(event);

          // parse event notes
          if (curInfo.notes != null)
            for (n in curInfo.notes)
              event.notes.push({ text: parse(n), isKnown: false, clues: 0 });

          // parse location (can be null!)
          var location = initLocation(curID, curInfo, curInfo.location, event);
          if (location != null)
            event.locationID = location.id;

          // create event npcs
          if (curInfo.npc != null)
            initNPC(curID, curInfo, curInfo.npc, event);

          // run init() function
          // note: it's after the static stuff because it can change event notes
          if (curInfo.init != null)
            curInfo.init(this);

          // timeline finish
          if (curInfo.next == null && curInfo.nextOR == null)
            break;

          // set next event
          if (curInfo.next != null)
            curID = curInfo.next;

          // set a random next event out of selection with chances
          else if (curInfo.nextOR != null)
            {
              // get a sum of chances
              var sum = 0;
              for (ch in curInfo.nextOR)
                sum += ch;

              // pick a random event
              var offset = 0;
              var rnd = Std.random(sum);
              var nextID = '';
              for (key in curInfo.nextOR.keys())
                {
                  var val = curInfo.nextOR.get(key);
                  if (rnd < offset + val)
                    {
                      nextID = key;
                      break;
                    }

                  offset += val;
                }

              if (curID == nextID)
                throw 'Could not pick a random next event in: ' + curInfo.nextOR;

              curID = nextID;
            }

          curInfo = scenario.flow.get(curID);
          if (curInfo == null)
            throw 'No such event in scenario: ' + curID;
        }
/*
      trace(_eventsList);
      trace(_names);
      trace(_locationsList);
*/
      game.info('Timeline variables: ' + _variables);

      // fix some goals text
//      scenario.onInit(game);
    }


// parse string with name templates and return it
  function parse(s: String): String
    {
      for (n in _names.keys())
        if (s.indexOf(n) >= 0)
          s = StringTools.replace(s, '%' + n + '%', _names.get(n));

      return s;
    }


// get location by id
  public function getLocation(id: String): Location
    {
      return _locationsMap[id];
    }


// get random event
  public inline function getRandomEvent(): Event
    {
      var arr = Lambda.array(_eventsMap);
      return arr[Std.random(arr.length)];
    }

// get random event that can be learned about
// NOTE: returns null if there is none
  public function getRandomLearnableEvent(): Event
    {
      var tmp = [];
      for (e in _eventsMap)
        {
          // hidden events
          if (e.isHidden)
            continue;
          // everything already known
          if (e.npcFullyKnown() &&
              e.notesKnown())
            continue;
          tmp.push(e);
        }
      if (tmp.length == 0)
        return null;
      return tmp[Std.random(tmp.length)];
    }

// get event by index
  public inline function getEventByIndex(idx: Int): Event
    {
      return _eventsList[idx];
    }

// get event by id
  public inline function getEvent(id: String): Event
    {
      return _eventsMap[id];
    }

// get event npc by id
  public function getEventNPC(id: String, npcID: Int): NPC
    {
      var e = getEvent(id);
      if (e == null)
        return null;
      return e.getNPC(npcID);
    }

// set timeline variable
  public inline function setVar(key: String, value: Dynamic)
    {
      _variables.set(key, value);
    }


// get timeline variable value
  public inline function getStringVar(key: String): String
    {
      return _variables.get(key);
    }


// get timeline variable value
  public inline function getIntVar(key: String): Int
    {
      var val = _variables.get(key);
      return (val != null ? val : 0);
    }

// get timeline variable value
// NOTE: we cannot store links here, they will not be serialized properly
  public inline function getDynamicVar(key: String)
    {
      return _variables.get(key);
    }

// get starting location event
  public inline function getStartEvent(): Event
    {
      return getEvent(scenario.playerStartEvent);
    }


// get goals map
  public inline function getGoals()
    {
      return scenario.goals;
    }

  public inline function debug(s)
    {
      game.debug(s);
    }
}

