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
  public inline function add(type: String, turns: Int)
    {
      addAI(null, type, turns);
    }


// add event by type originating from this ai
  public function addAI(ai: AI, type: String, turns: Int)
    {
      var e = {
        ai: ai,
        type: type,
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
          if (e.type == EVENT_CALL_POLICE)
            eventCallPolice(e.ai, e.details);
          
          _list.remove(e);
        }
    }


// event: civilian calls the police
  function eventCallPolice(ai: AI, reason: String)
    {
      log('Police have received reports about wild animal attacks. Dispatching available units to the location.');

      if (game.player.hears(ai.x, ai.y))
        ai.log('calls the police!');
    }


// log shortcut
  function log(s: String)
    {
      // TODO: add switch between debug mode and actual radio comms?
      game.log('DEBUG: ' + s, Const.COLOR_AREA);
    }


// =================================================================================

// event types
  public static var EVENT_CALL_POLICE = 'callPolice';
}


// area event type

typedef AreaEvent =
{
  var ai: AI; // ai event origin - can be null
  var details: String; // event details - can be null
  var type: String; // event type
  var turns: Int; // turns left until the event
};
