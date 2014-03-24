// area event manager - timer-related stuff, spawn stuff, despawn stuff, etc

import ai.*;
import objects.AreaObject;

class AreaManager 
{
  var game: Game;
  var _list: List<AreaEvent>;

  public var area: RegionArea; // current area link

  public function new(g: Game)
    {
      game = g;

      _list = new List<AreaEvent>();
    }


// DEBUG: show queue
  public function debugShowQueue()
    {
      for (e in _list)
        trace(e);
    }


// add event originating from x,y
  public inline function add(type: String, x: Int, y: Int, turns: Int)
    {
      var e = {
        ai: null,
        objectID: -1,
        details: null, 
        type: type,
        x: x,
        y: y,
        turns: turns
        };

      _list.push(e);
    }


// add event by type originating from this object 
  public inline function addObject(o: AreaObject, type: String, turns: Int)
    {
      var e = {
        ai: null,
        objectID: o.id,
        type: type,
        x: -1,
        y: -1,
        details: null, 
        turns: turns
        };

      _list.push(e);
    }



// add event by type originating from this ai
  public inline function addAI(ai: AI, type: String, turns: Int)
    {
      var e = {
        ai: ai,
        objectID: -1,
        type: type,
        x: ai.x,
        y: ai.y,
        details: ai.reason,
        turns: turns
        };

      _list.push(e);
    }


// area manager new turn
  public function turn()
    {
      for (e in _list)
        {
          // turns counter
          e.turns--;
          if (e.turns > 0)
            continue;

          // if ai origin is dead now, we skip this event
          if (e.ai != null && e.ai.state == AI.STATE_DEAD)
            {
              _list.remove(e);
              continue;
            }

          // if object origin is not in area now, we skip this event
          var o = (e.objectID >= 0 ? game.area.getObject(e.objectID) : null);
          if (e.objectID >= 0 && o == null) 
            {
              _list.remove(e);
              continue;
            }

          // run this event

          // someone called the police
          if (e.type == EVENT_CALL_POLICE)
            onCallPolice(e);

          // police is alerted
          else if (e.type == EVENT_ALERT_POLICE)
            onAlertPolice(e);

          // police arrives
          else if (e.type == EVENT_ARRIVE_POLICE)
            onArrivePolice(e);

          // police officer called for backup
          if (e.type == EVENT_CALL_POLICE_BACKUP)
            onCallPoliceBackup(e);

          // police backup arrives
          else if (e.type == EVENT_ARRIVE_POLICE_BACKUP)
            onArrivePoliceBackup(e);

          else if (e.type == EVENT_OBJECT_DECAY)
            onObjectDecay(o);

          _list.remove(e);
        }
    }


// ===============================  EVENTS  =========================================


// event: attack (called immediately)
  public function onAttack(x: Int, y: Int, isRanged: Bool)
    {
      var tmp = game.area.getAIinRadius(x, y, 
        (isRanged ? AI.HEAR_DISTANCE : AI.VIEW_DISTANCE), isRanged);
      for (ai in tmp)
        if (ai.state == AI.STATE_IDLE)
          ai.setState(AI.STATE_ALERT, AI.REASON_WITNESS);
    }


// event: civilian calls the police
  function onCallPolice(e: AreaEvent)
    {
      var sdetails;
      if (e.details == AI.REASON_HOST)
        sdetails = 'a suspicious individual';
      else if (e.details == AI.REASON_BODY)
        sdetails = 'a dead body';
      else if (e.details == AI.REASON_DAMAGE || e.details == AI.REASON_WITNESS)
        sdetails = 'an attack';
      else sdetails = 'wild animal sighting';

      log('Police has received a report about ' + sdetails + 
        '. Dispatching units to the location.');

      if (game.area.player.hears(e.ai.x, e.ai.y))
        e.ai.log('calls the police!');

      // increase area alertness
      area.alertness++;

      // alert all police already in area 
      add(EVENT_ALERT_POLICE, e.ai.x, e.ai.y, 2);

      // move on to arriving
      add(EVENT_ARRIVE_POLICE, e.ai.x, e.ai.y, 5);
    }


// event: alert police in area
  function onAlertPolice(e: AreaEvent)
    {
      var list = game.area.getAllAI();
      for (ai in list)
        if (ai.type == 'police' && ai.state == AI.STATE_IDLE)
          ai.setState(AI.STATE_ALERT, AI.REASON_BACKUP);
    }


// event: police arrives
  function onArrivePolice(e: AreaEvent)
    {
      log('Police arrives on scene!');

      for (i in 0...2)
        {
          var loc = game.area.findEmptyLocationNear(e.x, e.y);
          if (loc == null)
            {
              Const.todo('Could not find free spot for spawn!');
              return;
            }

          var ai = new PoliceAI(game, loc.x, loc.y);

          // called cops have guns
          ai.inventory.clear();
          ai.inventory.addID('pistol');
          ai.skills.addID('pistol', 25 + Std.random(25));

          // and arrive already alerted
          ai.alertness = 50;

          game.area.addAI(ai);
        }
    }


// event: police officer calls for backup 
  function onCallPoliceBackup(e: AreaEvent)
    {
      log('Officer calling for backup. Dispatching units to the location.');

      if (game.area.player.hears(e.ai.x, e.ai.y))
        e.ai.log('calls for backup!');

      // increase area alertness
      area.alertness += 2;

      // alert all police already in area 
      add(EVENT_ALERT_POLICE, e.ai.x, e.ai.y, 2);

      // move on to arriving
      add(EVENT_ARRIVE_POLICE_BACKUP, e.ai.x, e.ai.y, 5);
    }


// event: police backup arrives
  function onArrivePoliceBackup(e: AreaEvent)
    {
      log('Police backup arrives on scene!');

      for (i in 0...2)
        {
          var loc = game.area.findEmptyLocationNear(e.x, e.y);
          if (loc == null)
            {
              Const.todo('Could not find free spot for spawn!');
              return;
            }

          var ai = new PoliceAI(game, loc.x, loc.y);

          // called cops have guns
          ai.inventory.clear();
          ai.inventory.addID('pistol');
          ai.skills.addID('pistol', 25 + Std.random(25));

          // and arrive already alerted
/*          
          ai.alertness = 70;
*/        
          ai.timers.alert = 10;
          ai.state = AI.STATE_ALERT;
          ai.isBackup = true;

          game.area.addAI(ai);
        }
    }


// event: object decay
  function onObjectDecay(o: AreaObject)
    {
      game.area.removeObject(o);
    }


// ==================================================================================


// log shortcut
  inline function log(s: String)
    {
      // TODO: add switch between debug mode and actual radio comms?
      game.log('DEBUG: ' + s, Const.COLOR_AREA);
    }


// =================================================================================

// event types
  public static var EVENT_CALL_POLICE = 'callPolice';
  public static var EVENT_ALERT_POLICE = 'alertPolice';
  public static var EVENT_ARRIVE_POLICE = 'arrivePolice';
  public static var EVENT_CALL_POLICE_BACKUP = 'callPoliceBackup';
  public static var EVENT_ARRIVE_POLICE_BACKUP = 'arrivePoliceBackup';

  public static var EVENT_OBJECT_DECAY = 'objectDecay';
}


// area event type

typedef AreaEvent =
{
  var ai: AI; // ai event origin - can be null
  var objectID: Int; // area object event origin (-1: unused)
  var details: String; // event details - can be null
  var x: Int;
  var y: Int;
  var type: String; // event type
  var turns: Int; // turns left until the event
};
