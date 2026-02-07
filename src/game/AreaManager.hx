// area event manager - timer-related stuff, spawn stuff, despawn stuff, etc

package game;

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
// NOTE: params must be serializable!
  public inline function add(
      type: _AreaManagerEventType, x: Int, y: Int,
      turns: Int, ?params: _SaveObject = null)
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

          switch (e.type)
            {
              // someone called the law
              case AREAEVENT_CALL_LAW:
                onCallLaw(e);
              // law enforcement in area is alerted
              case AREAEVENT_ALERT_LAW:
                onAlertLaw(e);
              // law arrives
              case AREAEVENT_ARRIVE_LAW:
                onArriveLaw(e);
              // police/security/army called for backup
              case AREAEVENT_CALL_BACKUP:
                onCallBackup(e);
              // backup arrives
              case AREAEVENT_ARRIVE_BACKUP:
                onArriveBackup(e);
              // team called for backup
              case AREAEVENT_CALL_TEAM_BACKUP:
                onCallTeamBackup(e);
              // team backup arrives
              case AREAEVENT_ARRIVE_TEAM_BACKUP:
                onArriveTeamBackup(e);
              // object decay
              case AREAEVENT_OBJECT_DECAY:
                onObjectDecay(o);
              // cultist help arrives
              case AREAEVENT_ARRIVE_CULTIST:
                game.cults[0].onArriveCultist(e);
            }
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
        if (ai.state == AI_STATE_IDLE ||
            ai.state == AI_STATE_MOVE_TARGET)
          ai.setState(AI_STATE_ALERT, REASON_WITNESS);
    }


// event: civilian calls the law
  function onCallLaw(e: AreaEvent)
    {
      // attached parasite can stop phone/radio calls
      if (game.player.difficulty == UNSET ||
          game.player.difficulty == EASY)
        {
          if ((game.player.state == PLR_STATE_HOST &&
                game.player.host == e.ai) ||
              (game.player.state == PLR_STATE_ATTACHED &&
               game.playerArea.attachHost == e.ai))
            {
              game.log('You have managed to stop ' + e.ai.getName() + ' from calling the authorities.');
              return;
            }
        }

      // pick reason and area alertness/group prio points
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

      game.scene.sounds.play('ai-phone', {
        x: e.ai.x,
        y: e.ai.y,
        canDelay: true,
        always: false,
      });
      // high crime area has a chance of not responding
      if (area.highCrime && Std.random(100) < 80)
        {
          log(Const.capitalize(area.info.lawType) +
            ' has received reports about ' + sdetails +
            '. Units were not dispatched.');
          return;
        }
      log(Const.capitalize(area.info.lawType) +
        ' has received reports about ' + sdetails +
        '. Dispatching units to the location.');

      // raise group priority
      game.group.raisePriority(pts);

      if (game.playerArea.hears(e.ai.x, e.ai.y))
        {
          if (game.player.skills.getLevel(KNOW_SOCIETY) < 5)
            e.ai.log('calls someone!');
          else e.ai.log('calls the ' +
            area.info.lawType + '!',
            COLOR_ALERT);
        }

      // increase area alertness
      area.alertness += apts;

      // alert all police already in area
      add(AREAEVENT_ALERT_LAW, e.ai.x, e.ai.y, 2);

      // move on to arriving
      add(AREAEVENT_ARRIVE_LAW, e.ai.x, e.ai.y, area.info.lawResponseTime);
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
      // check for max law
      var cnt = getLawCount();
      if (cnt >= area.info.lawResponseMax)
        return;

      log(Const.capitalize(area.info.lawType) +
        ' arrives on scene!');
      game.scene.sounds.play('ai-arrive-' + area.info.lawType, {
        x: e.x,
        y: e.y,
        canDelay: true,
        always: false,
      });

      // spawn ai
      for (_ in 0...area.info.lawResponseAmount)
        {
          var loc = area.findArriveLocation({
            near: { x: e.x, y: e.y },
            radius: 5,
            fallbackRadius: 0
          });
          if (loc == null)
            {
              Const.todo('Could not find free spot for spawn (law)!');
              return;
            }

          // spawn ai, set move target
          var ai = area.spawnAI(area.info.lawType, loc.x, loc.y);
          ai.roamTargetX = e.x;
          ai.roamTargetY = e.y;

          // called law has guns
          ai.inventory.clear();
          ai.inventory.addID('pistol');
          ai.skills.addID(SKILL_PISTOL, 25 + Std.random(25));

          // and arrives already alerted
          ai.alertness = 50;
        }
    }


// event: police/security/army calls for backup
  function onCallBackup(e: AreaEvent)
    {
      game.scene.sounds.play('ai-radio', {
        x: e.ai.x,
        y: e.ai.y,
        canDelay: true,
        always: false,
      });
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
      var params: _AreaManagerEventParamsArriveBackup = {
        type: e.ai.type,
      };
      add(AREAEVENT_ARRIVE_BACKUP, e.ai.x, e.ai.y,
        area.info.lawResponseTime, params);
    }

// helper: get law ai number around player
// NOTE: the trick is that we're counting the AI near player, not event
// and we ignore los
  function getLawCount(): Int
    {
      var list = area.getAIinRadius(game.playerArea.x, game.playerArea.y,
        15, false);
      var cnt = 0;
      for (ai in list)
        if (ai.type == 'police' ||
            ai.type == 'security' ||
            ai.type == 'soldier')
          cnt++;
      return cnt;
    }

// event: law enf. backup arrives
  function onArriveBackup(e: AreaEvent)
    {
      // check for max law
      var cnt = getLawCount();
      if (cnt >= area.info.lawResponseMax)
        return;

      log('Backup arrives on scene!');
      game.scene.sounds.play('ai-arrive-' + e.params.type, {
        x: e.x,
        y: e.y,
        canDelay: true,
        always: false,
      });
      for (i in 0...2)
        {
          var loc = area.findArriveLocation({
            near: { x: e.x, y: e.y },
            radius: 5,
            fallbackRadius: 0
          });
          if (loc == null)
            {
              Const.todo('Could not find free spot for spawn (area)!');
              return;
            }

          var ai = area.spawnAI(e.params.type, loc.x, loc.y);
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
        }
    }


// event: team member calls for backup
  function onCallTeamBackup(e: AreaEvent)
    {
      game.scene.sounds.play('ai-radio', {
        x: e.ai.x,
        y: e.ai.y,
        canDelay: true,
        always: false,
      });
      log('Team member calling for backup. Dispatching units to the location.');

      if (game.playerArea.hears(e.ai.x, e.ai.y))
        e.ai.log('calls for backup!');

      game.group.raisePriority(5);

      // move on to arriving
      add(AREAEVENT_ARRIVE_TEAM_BACKUP, e.ai.x, e.ai.y, 3, null);
    }

// helper: get blackops ai number around player
// NOTE: the trick is that we're counting the AI near player, not event
// and we ignore los
  function getTeamCount(): Int
    {
      var list = area.getAIinRadius(game.playerArea.x, game.playerArea.y,
        15, false);
      var cnt = 0;
      for (ai in list)
        if (ai.type == 'blackops')
          cnt++;
      return cnt;
    }

// event: team backup arrives
  function onArriveTeamBackup(e: AreaEvent)
    {
      // in rare case, team can get deleted by raiseTeamDistance() while backup is on the way
      if (game.group.team == null)
        return;
      // check for max blackops
      // NOTE: use law response max number if it is there
      var cnt = getLawCount();
      var max = (area.info.lawResponseMax > 0 ? area.info.lawResponseMax : 4);
      if (cnt >= max)
        return;

      log('Backup arrives on scene!');
      game.scene.sounds.play('ai-arrive-security', {
        x: e.x,
        y: e.y,
        canDelay: true,
        always: false,
      });

      for (i in 0...2)
        {
          var loc = area.findArriveLocation({
            near: { x: e.x, y: e.y },
            radius: 10,
            fallbackRadius: 5
          });
          if (loc == null)
            {
              Const.todo('Could not find free spot for spawn (team backup)!');
              return;
            }

          var ai = area.spawnAI('blackops', loc.x, loc.y);

          // arrives already alerted
          ai.timers.alert = 10;
          ai.state = AI_STATE_ALERT;

          // set roam target
          ai.roamTargetX = e.x;
          ai.roamTargetY = e.y;
        }
    }


// event: object decay
// NOTE: despawn != decay
  function onObjectDecay(o: AreaObject)
    {
      o.onDecay();
      area.removeObject(o);
    }

// log shortcut
  inline function log(s: String)
    {
      // TODO: add switch between debug mode and actual radio comms?
//      game.log(s, COLOR_AREA);
      game.debug(s);
    }

// get list of events
  public function getList(): List<AreaEvent>
    {
      return _list;
    }

  function get_area(): AreaGame
    {
      return game.area;
    }
}


@:structInit
class _AreaManagerEventParamsArriveBackup extends _SaveObject
{
  public var type: String;

  public function new(type: String)
    {
      this.type = type;
    }

  public function init()
    {}
}
