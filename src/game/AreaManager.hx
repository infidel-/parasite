// area event manager - timer-related stuff, spawn stuff, despawn stuff, etc

package game;

import ai.*;
import ai.AI;
import objects.AreaObject;

class AreaManager
{
  var game: Game;
  var _list: List<AreaEvent>;

  var area(get, null): AreaGame; // current area link

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
  public inline function add(type: _AreaManagerEventType, x: Int, y: Int,
      turns: Int, ?params: Dynamic = null)
    {
      var e = {
        ai: null,
        objectID: -1,
        details: null,
        type: type,
        x: x,
        y: y,
        turns: turns,
        params: params
        };

      _list.push(e);
    }


// add event by type originating from this object
  public inline function addObject(o: AreaObject, type: _AreaManagerEventType,
      turns: Int)
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
  public inline function addAI(ai: AI, type: _AreaManagerEventType, turns: Int)
    {
      var e = {
        ai: ai,
        objectID: -1,
        type: type,
        x: ai.x,
        y: ai.y,
        details: '' + ai.reason,
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
          if (e.ai != null && e.ai.state == AI_STATE_DEAD)
            {
              _list.remove(e);
              continue;
            }

          // if object origin is not in area now, we skip this event
          var o = (e.objectID >= 0 ? area.getObject(e.objectID) : null);
          if (e.objectID >= 0 && o == null)
            {
              _list.remove(e);
              continue;
            }

          // run this event

          // someone called the law
          if (e.type == AREAEVENT_CALL_LAW)
            onCallLaw(e);

          // law enforcement in area is alerted
          else if (e.type == AREAEVENT_ALERT_LAW)
            onAlertLaw(e);

          // law arrives
          else if (e.type == AREAEVENT_ARRIVE_LAW)
            onArriveLaw(e);

          // police/security/army called for backup
          else if (e.type == AREAEVENT_CALL_BACKUP)
            onCallBackup(e);

          // backup arrives
          else if (e.type == AREAEVENT_ARRIVE_BACKUP)
            onArriveBackup(e);

          // team called for backup
          else if (e.type == AREAEVENT_CALL_TEAM_BACKUP)
            onCallTeamBackup(e);

          // team backup arrives
          else if (e.type == AREAEVENT_ARRIVE_TEAM_BACKUP)
            onArriveTeamBackup(e);

          // object decay
          else if (e.type == AREAEVENT_OBJECT_DECAY)
            onObjectDecay(o);

          _list.remove(e);
        }
    }


// ===============================  EVENTS  =========================================


// event: attack (called immediately)
  public function onAttack(x: Int, y: Int, isRanged: Bool)
    {
      var tmp = area.getAIinRadius(x, y,
        (isRanged ? AI.HEAR_DISTANCE : AI.VIEW_DISTANCE), isRanged);
      for (ai in tmp)
        if (ai.state == AI_STATE_IDLE)
          ai.setState(AI_STATE_ALERT, REASON_WITNESS);
    }


// event: civilian calls the law
  function onCallLaw(e: AreaEvent)
    {
      var sdetails;
      var pts = 0;
      if (e.details == '' + REASON_HOST)
        {
          sdetails = 'a suspicious individual';
          pts = 2;
        }
      else if (e.details == '' + REASON_BODY)
        sdetails = 'a dead body';
      else if (e.details == '' + REASON_WITNESS)
        {
          sdetails = 'an attack';
          pts = 1;
        }
      else if (e.details == '' + REASON_DAMAGE)
        {
          sdetails = 'an attack';
          pts = 2;
        }
      else
        {
          sdetails = 'wild animal sighting';
          pts = 1;
        }

      log((area.typeID == AREA_FACILITY ? 'Security' : 'Police') +
        ' has received a report about ' + sdetails +
        '. Dispatching units to the location.');

      game.group.raisePriority(pts);

      if (game.playerArea.hears(e.ai.x, e.ai.y))
        e.ai.log('calls the ' +
          (area.typeID == AREA_FACILITY ? 'security' : 'police') + '!');

      // increase area alertness
      area.alertness++;

      // alert all police already in area
      add(AREAEVENT_ALERT_LAW, e.ai.x, e.ai.y, 2);

      // move on to arriving
      add(AREAEVENT_ARRIVE_LAW, e.ai.x, e.ai.y, area.info.lawResponceTime);
    }


// event: alert law enf. in area
  function onAlertLaw(e: AreaEvent)
    {
      var list = area.getAllAI();
      for (ai in list)
        if (Lambda.has([ 'police', 'security', 'soldier' ], ai.type) &&
            ai.state == AI_STATE_IDLE)
          ai.setState(AI_STATE_ALERT, REASON_BACKUP);
    }


// event: law arrives
  function onArriveLaw(e: AreaEvent)
    {
      log((area.typeID == AREA_FACILITY ? 'Security' : 'Police') +
        ' arrives on scene!');

      for (i in 0...area.info.lawResponceAmount)
        {
          var loc = area.findLocation({
            near: { x: e.x, y: e.y },
            radius: 5,
            isUnseen: true
            });
          if (loc == null)
            {
              Const.todo('Could not find free spot for spawn!');
              return;
            }

          var ai: AI = null;
          if (area.typeID == AREA_FACILITY)
            ai = new SecurityAI(game, loc.x, loc.y);
          else ai = new PoliceAI(game, loc.x, loc.y);

          // set roam target
          ai.roamTargetX = e.x;
          ai.roamTargetY = e.y;

          // called law has guns
          ai.inventory.clear();
          ai.inventory.addID('pistol');
          ai.skills.addID(SKILL_PISTOL, 25 + Std.random(25));

          // and arrives already alerted
          ai.alertness = 50;

          area.addAI(ai);
        }
    }


// event: police/security/army calls for backup
  function onCallBackup(e: AreaEvent)
    {
      log((e.ai.type == 'police' ? 'Officer' : 'Unit') +
        ' calling for backup. Dispatching units to the location.');

      if (game.playerArea.hears(e.ai.x, e.ai.y))
        e.ai.log('calls for backup!');

      game.group.raisePriority(1);

      // increase area alertness
      area.alertness += 2;

      // alert all law already in area
      add(AREAEVENT_ALERT_LAW, e.ai.x, e.ai.y, 2);

      // move on to arriving
      add(AREAEVENT_ARRIVE_BACKUP, e.ai.x, e.ai.y, area.info.lawResponceTime,
        { type: e.ai.type });
    }


// event: law enf. backup arrives
  function onArriveBackup(e: AreaEvent)
    {
      log('Backup arrives on scene!');

      for (i in 0...2)
        {
          var loc = area.findEmptyLocationNear(e.x, e.y);
          if (loc == null)
            {
              Const.todo('Could not find free spot for spawn!');
              return;
            }

          var ai: AI = null;
          if (e.params.type == 'police')
            ai = new PoliceAI(game, loc.x, loc.y);
          else if (e.params.type == 'security')
            ai = new SecurityAI(game, loc.x, loc.y);
          else if (e.params.type == 'soldier')
            ai = new SoldierAI(game, loc.x, loc.y);

          // backup has better equipment
          ai.inventory.clear();
          if (e.params.type == 'police')
            {
              ai.inventory.addID('pistol');
              ai.skills.addID(SKILL_PISTOL, 25 + Std.random(25));
            }

          else if (e.params.type == 'security')
            {
              ai.inventory.addID('pistol');
              ai.skills.addID(SKILL_PISTOL, 50 + Std.random(25));
            }

          else if (e.params.type == 'soldier')
            {
              ai.inventory.addID('assaultRifle');
              ai.skills.addID(SKILL_RIFLE, 50 + Std.random(25));
            }


          // and arrive already alerted
/*
          ai.alertness = 70;
*/
          ai.timers.alert = 10;
          ai.state = AI_STATE_ALERT;
          untyped ai.isBackup = true;

          area.addAI(ai);
        }
    }


// event: team member calls for backup
  function onCallTeamBackup(e: AreaEvent)
    {
      log('Team member calling for backup. Dispatching units to the location.');

      if (game.playerArea.hears(e.ai.x, e.ai.y))
        e.ai.log('calls for backup!');

      game.group.raisePriority(5);

      // move on to arriving
      add(AREAEVENT_ARRIVE_TEAM_BACKUP, e.ai.x, e.ai.y, 3, {});
    }


// event: team backup arrives
  function onArriveTeamBackup(e: AreaEvent)
    {
      log('Backup arrives on scene!');

      for (i in 0...2)
        {
          var loc = game.area.findLocation({
            near: { x: e.x, y: e.y },
            radius: 10,
            isUnseen: true
            });
          if (loc == null)
            {
              loc = area.findEmptyLocationNear(e.x, e.y);
              if (loc == null)
                {
                  Const.todo('Could not find free spot for spawn x2!');
                  return;
                }
            }

          var ai = new BlackopsAI(game, loc.x, loc.y);

          // and arrive already alerted
          ai.timers.alert = 10;
          ai.state = AI_STATE_ALERT;

          // set roam target
          ai.roamTargetX = e.x;
          ai.roamTargetY = e.y;

          area.addAI(ai);
        }
    }


// event: object decay
  function onObjectDecay(o: AreaObject)
    {
      area.removeObject(o);
    }


// ==================================================================================


// log shortcut
  inline function log(s: String)
    {
      // TODO: add switch between debug mode and actual radio comms?
//      game.log(s, COLOR_AREA);
      game.debug(s);
    }


  function get_area(): AreaGame
    {
      return game.area;
    }
}


// area event type

typedef AreaEvent =
{
  var ai: AI; // ai event origin - can be null
  var objectID: Int; // area object event origin (-1: unused)
  var details: String; // event details - can be null
  var x: Int;
  var y: Int;
  var type: _AreaManagerEventType; // event type
  var turns: Int; // turns left until the event
  @:optional var params: Dynamic; // additional parameters
};
