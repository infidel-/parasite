// area event manager - timer-related stuff, spawn stuff, despawn stuff, etc

package game;

import ai.*;
import ai.AI;
import objects.AreaObject;

class AreaManager extends _SaveObject
{
  var game: Game;
  var _list: List<AreaEvent>;
  var lastEventID: Int;

  var area(get, null): AreaGame; // current area link

  public function new(g: Game)
    {
      game = g;

      _list = new List<AreaEvent>();
      lastEventID = 1;
    }

// called after loading
  public function loadPost()
    {
      for (ev in _list)
        if (ev.aiID >= 0)
          ev.ai = area.getAIByID(ev.aiID);
    }

#if mydebug
  public function debugInfo(buf: StringBuf)
    {
      if (_list.length > 0)
        buf.add('<hr>');
      for (e in _list)
        buf.add(e.type + ': ' + e.turns + '<br>');
    }
#end

// add event originating from x,y
  public inline function add(type: _AreaManagerEventType, x: Int, y: Int,
      turns: Int, ?params: Dynamic = null)
    {
      var e: AreaEvent = {
        id: lastEventID++,
        ai: null,
        objectID: -1,
        details: null,
        type: type,
        x: x,
        y: y,
        turns: turns,
        params: params
      };
#if mydebug
//      Const.p(game.turns + ': AreaManager.add(): ' + e);
#end

      _list.push(e);
    }


// add event by type originating from this object
  public inline function addObject(o: AreaObject, type: _AreaManagerEventType,
      turns: Int)
    {
      var e: AreaEvent = {
        id: lastEventID++,
        ai: null,
        objectID: o.id,
        type: type,
        x: -1,
        y: -1,
        details: null,
        turns: turns,
        params: null,
      };
#if mydebug
 //     Const.p(game.turns + ': AreaManager.addObject(): ' + e);
#end

      _list.push(e);
    }



// add event by type originating from this ai
  public inline function addAI(ai: AI, type: _AreaManagerEventType, turns: Int)
    {
      var e: AreaEvent = {
        id: lastEventID++,
        ai: ai,
        objectID: -1,
        type: type,
        x: ai.x,
        y: ai.y,
        details: '' + ai.reason,
        turns: turns,
        params: null,
      };
#if mydebug
//      Const.p(game.turns + ': AreaManager.addAI(): ' + e);
#end

      _list.push(e);
    }

// returns true if there is this event from this ai
  public function hasAI(ai: AI, type: _AreaManagerEventType): Bool
    {
      for (e in _list)
        if (e.ai == ai && e.type == type)
          return true;
      return false;
    }


// clean old events on leaving area
  public function onLeaveArea()
    {
      _list.clear();
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
#if mydebug
//      Const.p(game.turns + ': AreaManager.run(): ' + e.id + ' ' + e.type);
#end

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
      if (game.player.difficulty == UNSET ||
          game.player.difficulty == EASY)
        {
          if ((game.player.state == PLR_STATE_HOST && game.player.host == e.ai) ||
              (game.player.state == PLR_STATE_ATTACHED && game.playerArea.attachHost == e.ai))
            {
              game.log('You have managed to stop ' + e.ai.getName() + ' from calling the authorities.');
              return;
            }
        }
      var sdetails;
      var apts = 0;
      var pts = 0;
      if (e.details == '' + REASON_HOST)
        {
          sdetails = 'a suspicious individual';
          apts = 5;
          pts = 2;
        }
      else if (e.details == '' + REASON_BODY)
        {
          sdetails = 'a dead body';
          apts = 10;
          pts = 0;
        }
      else if (e.details == '' + REASON_WITNESS)
        {
          sdetails = 'an attack';
          apts = 5;
          pts = 1;
        }
      else if (e.details == '' + REASON_DAMAGE)
        {
          sdetails = 'an attack';
          apts = 10;
          pts = 2;
        }
      else
        {
          sdetails = 'wild animal sighting';
          apts = 5;
          pts = 1;
        }

      log((area.typeID == AREA_FACILITY ? 'Security' : 'Police') +
        ' has received reports about ' + sdetails +
        '. Dispatching units to the location.');

      game.group.raisePriority(pts);

      if (game.playerArea.hears(e.ai.x, e.ai.y))
        {
          if (game.player.skills.getLevel(KNOW_SOCIETY) < 5)
            e.ai.log('calls someone!');
          else e.ai.log('calls the ' +
            (area.typeID == AREA_FACILITY ? 'security' : 'police') + '!',
            COLOR_ALERT);
        }

      // increase area alertness
      area.alertness += apts;

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
              Const.todo('Could not find free spot for spawn (law)!');
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
      area.alertness += 20;

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
          var loc = area.findEmptyLocationNear(e.x, e.y, 5);
          if (loc == null)
            {
              Const.todo('Could not find free spot for spawn (area)!');
              return;
            }

          var ai: AI = null;
          if (e.params.type == 'police')
            ai = new PoliceAI(game, loc.x, loc.y);
          else if (e.params.type == 'security')
            ai = new SecurityAI(game, loc.x, loc.y);
          else if (e.params.type == 'soldier')
            ai = new SoldierAI(game, loc.x, loc.y);
          ai.isCommon = false;

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
      // in rare case, team can get deleted by raiseTeamDistance() while backup is on the way
      if (game.group.team == null)
        return;
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
              loc = area.findEmptyLocationNear(e.x, e.y, 5);
              if (loc == null)
                {
                  Const.todo('Could not find free spot for spawn (team backup)!');
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

