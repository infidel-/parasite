// event timeline

package scenario;

import scenario.Scenario;

class Timeline
{
  var game: Game;
  var scenario: Scenario;
  public var isLocked: Bool; // is timeline screen locked?

  var _eventsMap: Map<String, Event>; // events hash map
  var _eventsList: Array<Event>; // ordered events list
  var _locationsList: List<Location>; // ordered locations list
  var _names: Map<String, String>; // fully parsed from templates names
  var _variables: Map<String, Dynamic>; // timeline variables map 

  public function new(g: Game)
    {
      game = g;

      _eventsMap = new Map();
      _eventsList = []; 
      _locationsList = new List();
      _variables = new Map<String, Dynamic>();
      _names = new Map();
      isLocked = true;
    }


  public function iterator()
    {
      return _eventsList.iterator();
    }


// get a clue for this event
  public function getClue(e: Event)
    {
      game.player.log('You have gained a clue for event ' + e.num + '.',
        COLOR_TIMELINE);
    }


// parse scenario names
  function parseNames()
    {
      for (key in scenario.names.keys())
        {
          var tmp = scenario.names.get(key);
          var name = tmp[Std.random(tmp.length)];

          // %num?% => random numbers
          if (name.indexOf('%num') > 0)
            for (i in 0...9)
              name = StringTools.replace(name, '%num' + i + '%', '' + Std.random(10));

          // %letter?% => random letter A-Z 
          if (name.indexOf('%letter') > 0)
            for (i in 0...9)
              name = StringTools.replace(name, '%letter' + i + '%',
                String.fromCharCode(65 + Std.random(26)));

          // %greek?% => random greek letter 
          if (name.indexOf('%greek') > 0)
            for (i in 0...9)
              name = StringTools.replace(name, '%greek' + i + '%',
                Const.greekLetters[Std.random(Const.greekLetters.length)]);

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
      var tmp = getLocation(info.id);
      if (tmp != null)
        return tmp;

      // copy location from previous event
      if (info.sameAs != null)
        {
          var tmp = getEvent(info.sameAs);
          if (tmp.location == null)
            throw '' + info + ': event ' + info.sameAs + ' does not have location.';

          return tmp.location;
        }

      var location = new Location(info.id);
      if (info.name != null)
        {
          location.name = parse(info.name);
          location.hasName = true;
        }

      if (info.type == null)
        {
          var tmp = [ ConstWorld.AREA_CITY_LOW,
            ConstWorld.AREA_CITY_MEDIUM, ConstWorld.AREA_CITY_HIGH ];
          info.type = tmp[Std.random(tmp.length)];
        }

      // find area with this type
      // single region atm
      var region = game.world.get(0);
      var area = region.getRandomWithType(info.type, true);
      if (area == null)
        area = region.spawnArea(info.type, true);
      location.area = area;
      area.event = event;

      // location is near this event id
      if (info.near != null)
        {
          Const.todo('LocationInfo.near: ' + info);
        }

      _locationsList.add(location);
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

      Const.todo('change actual npc type');
      for (type in npc.keys())
        {
          var max = npc.get(type);
          if (max > 3)
            max = Std.int(max / 2) + Std.random(Std.int(max / 2));
          for (i in 0...max)
            {
              var npc = new NPC();
              npc.event = event;
              npc.job = type;
              var region = game.world.get(0);
              if (event.location != null)
                npc.area = region.getRandomAround(event.location.area);
              else
                {
                  Const.todo('spawn event npcs in appropriate area types');
                  var tmp = [ ConstWorld.AREA_CITY_LOW,
                    ConstWorld.AREA_CITY_MEDIUM, ConstWorld.AREA_CITY_HIGH ];
                  npc.area = region.getRandomWithType(tmp[Std.random(tmp.length)], false);
                }

              npc.area.npc.add(npc);
          
              // event coverup kills some npcs
              if (total > 3)
                npc.isDead = (Std.random(100) < 50 ? true : false);

              event.npc.push(npc);
            }
        }
    }


// init a new scenario
  public function init()
    {
      scenario = new ScenarioAlienCrashLanding();

      // parse names
      parseNames();

      // walk through available events generating a new timeline
      var n = 1;
      var curID = scenario.startEvent;
      var curInfo = scenario.flow.get(scenario.startEvent);
      while (true)
        {
          var event = new Event(curID);
          event.num = n++;
          event.name = curInfo.name;
          event.isHidden = (curInfo.isHidden == true);
          _eventsMap.set(curID, event);
          _eventsList.push(event);

          // set timeline variables
          if (curInfo.setVariables != null)
            for (key in curInfo.setVariables.keys())
              _variables.set(key, curInfo.setVariables.get(key));

          // call a function that sets timeline variables
          if (curInfo.setVariablesFunc != null)
            {
              var tmpList = curInfo.setVariablesFunc();
              if (tmpList != null)
                for (tmp in tmpList)
                  _variables.set(tmp.key, tmp.val); 
            }

          // parse event notes
          if (curInfo.notes != null)
            for (n in curInfo.notes)
              event.notes.push({ text: parse(n), isKnown: false, clues: 0 });

          // parse location
          event.location = initLocation(curID, curInfo, curInfo.location, event);

          // create event npcs
          if (curInfo.npc != null)
            initNPC(curID, curInfo, curInfo.npc, event);

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
      trace(_variables);
      trace(_locationsList);
*/
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
      for (l in _locationsList)
        if (l.id == id)
          return l;

      return null;
    }


// get event by id
  public inline function getEvent(id: String): Event
    {
      return _eventsMap.get(id);
    }


// get starting location event
  public inline function getStartEvent(): Event
    {
      return getEvent(scenario.playerStartLocation);
    }
}

