// area event manager - timer-related stuff, spawn stuff, despawn stuff, etc

class AreaManager 
{
  var game: Game;
  var _list: List<AreaEvent>;

  public function new(g: Game)
    {
      game = g;

      _list = new List<AreaEvent>();
    }


// add event shortcut
  public inline function add(type: String, x: Int, y: Int, turns: Int)
    {
      var e = {
        ai: null,
        details: null, 
        type: type,
        x: x,
        y: y,
        turns: turns
        };

      _list.push(e);
    }


// add event by type originating from this ai
  public inline function addAI(ai: AI, type: String, turns: Int)
    {
      var e = {
        ai: ai,
        type: type,
        x: ai.x,
        y: ai.y,
        details: (ai != null ? ai.reason : null),
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

          // run this event

          // someone called the police
          if (e.type == EVENT_CALL_POLICE)
            onCallPolice(e);

          // police arrives
          else if (e.type == EVENT_ARRIVE_POLICE)
            onArrivePolice(e);

          _list.remove(e);
        }
    }


// ===============================  EVENTS  =========================================


// event: attack (called immediately)
  public function onAttack(x: Int, y: Int, isRanged: Bool)
    {
      var tmp = game.area.getAIinRadius(x, y, 
        (isRanged ? Const.AI_HEAR_DISTANCE : Const.AI_VIEW_DISTANCE), isRanged);
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
      else if (e.details == AI.REASON_DAMAGE || e.details == AI.REASON_WITNESS)
        sdetails = 'an attack';
      else sdetails = 'wild animal attack';

      log('Police has received a report about ' + sdetails + 
        '. Dispatching available units to the location.');

      if (game.player.hears(e.ai.x, e.ai.y))
        e.ai.log('calls the police!');

      // move on to arriving
      add(EVENT_ARRIVE_POLICE, e.ai.x, e.ai.y, 5);
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
          ai.alertness = 50; // AI arrive already somewhat alerted
          game.area.addAI(ai);
        }
    }


// ==================================================================================


// log shortcut
  function log(s: String)
    {
      // TODO: add switch between debug mode and actual radio comms?
      game.log('DEBUG: ' + s, Const.COLOR_AREA);
    }


// =================================================================================

// event types
  public static var EVENT_CALL_POLICE = 'callPolice';
  public static var EVENT_ARRIVE_POLICE = 'arrivePolice';
}


// area event type

typedef AreaEvent =
{
  var ai: AI; // ai event origin - can be null
  var details: String; // event details - can be null
  var x: Int;
  var y: Int;
  var type: String; // event type
  var turns: Int; // turns left until the event
};
