// NPC AI game state

import entities.AIEntity;

class AI
{
  var game: Game; // game state link

  public var entity: AIEntity; // gui entity
  public var type: String; // object type
  public var name: String; // AI name (can be unique and capitalized)
  public var isAggressive: Bool; // true - attack in alerted state, false - run away

  public var x: Int; // grid x,y
  public var y: Int;
  var direction: Int; // direction of movement

  public var state: String; // AI state
  public var reason: String; // reason for setting this state 
  public var alertness(default, set): Int; // 0-100, how alert is AI to the parasite
  public var alertTimer: Int; // when alerted, this will go down until AI calms down

  // stats
  public var strength: Int; // physical strength (1-10)
  public var constitution: Int; // physical constitution (1-10)
  public var intellect: Int; // mental capability (1-10)
  public var psyche: Int; // mental strength (1-10)
  public var health(default, set): Int; // current health
  public var maxHealth: Int; // maximum health
  public var hostExpiryTurns: Int; // amount of turns until this host expires

  public var inventory: Inventory; // AI inventory
  public var skills: Skills; // AI skills

  // state vars
  public var parasiteAttached: Bool; // is parasite currently attached to this AI

  public function new(g: Game, vx: Int, vy: Int)
    {
      game = g;
      type = 'undefined';

      x = vx;
      y = vy;

      state = STATE_IDLE;
      reason = REASON_NONE;
      alertness = 0;
      alertTimer = 0;
      direction = 0;
      isAggressive = false;
      parasiteAttached = false;
      strength = 1;
      constitution = 1;
      intellect = 1;
      psyche = 1;
      maxHealth = 1;
      health = 1;
      hostExpiryTurns = 10;

      inventory = new Inventory();
      skills = new Skills();
    }


// save derived stats (must be called in the end of derived classes constructors)
  function derivedStats()
    {
      hostExpiryTurns = (5 + strength + constitution) * 10;
//      maxHealth = Std.int(strength / 2) + constitution;
      maxHealth = strength + constitution;
      health = maxHealth;
    }


// create entity for this AI
  public function createEntity()
    {
      var atlasRow: Dynamic = Reflect.field(Const, 'ROW_' + type.toUpperCase());
      if (atlasRow == null)
        {
          trace('No such entity type: ' + type);
          return;
        }
      entity = new AIEntity(this, game, x, y, atlasRow);
      game.scene.add(entity);
    }


// set position
  public function setPosition(vx: Int, vy: Int)
    {
      x = vx;
      y = vy;
      entity.setPosition(x, y);
    }


// internal: change direction at random to the empty space
  function changeRandomDirection()
    {
/*    
      // form a temp list of walkable dirs
      var tmp = [];
      for (i in 0...Const.dirx.length)
        {
          var nx = x + Const.dirx[i];
          var ny = y + Const.diry[i];
          var ok = 
            (game.area.isWalkable(nx, ny) && 
             !game.area.hasAI(nx, ny) && 
             !(game.player.x == nx && game.player.y == ny));
          if (ok)
            tmp.push(i);
        }

      // nowhere to go, return
      if (tmp.length == 0)
        {
          trace('ai at (' + x + ',' + y + '): no dirs');
          return;
        }

      direction = tmp[Std.random(tmp.length)];
*/
      direction = game.area.getRandomDirection(x, y);
      if (direction == -1)
        trace('ai at (' + x + ',' + y + '): nowhere to move!');
/*      
      if (x < 20 && y < 20) 
        trace(tmp + ' ai at (' + x + ',' + y + '): dir' + direction +
          ' n:' + (x + Const.dirx[direction]) + ',' + (y + Const.diry[direction]));
*/          
    }


// does this AI sees this position?
  function seesPosition(xx: Int, yy: Int): Bool
    {
      // too far away
      var distSqr = Const.getDistSquared(x, y, xx, yy);
      if (distSqr > Const.AI_VIEW_DISTANCE * Const.AI_VIEW_DISTANCE)
        return false;

      // check for visibility
      if (!game.area.isVisible(x, y, xx, yy))
        return false;

      return true;
    }


// set AI state (plus all vars for this state)
  public function setState(vstate: String, ?vreason: String = 'none')
    {
      state = vstate;
      reason = vreason;
      if (state == STATE_ALERT)
        alertTimer = Const.AI_ALERTED_TIMER;

      // dynamic event
      onStateChange();
    }


// post alert changes, clamp and change icon
  function updateEntity()
    {
      var alertFrame = Const.FRAME_EMPTY;
      if (state == STATE_ALERT)
        alertFrame = Const.FRAME_ALERTED;
      else if (state == STATE_IDLE)
        {
          if (alertness > 75)
            alertFrame = Const.FRAME_ALERT3;
          else if (alertness > 50)
            alertFrame = Const.FRAME_ALERT2;
          else if (alertness > 0)
            alertFrame = Const.FRAME_ALERT1;
        }

      entity.setAlert(alertFrame);
    }


// ===================================  LOGIC  =======================================


// logic: roam around (default)
  public function logicRoam()
    {
      if (Math.random() < 0.2)
        changeRandomDirection();

      var nx = x + Const.dirx[direction];
      var ny = y + Const.diry[direction];
      var ok = 
        (game.area.isWalkable(nx, ny) && 
         !game.area.hasAI(nx, ny) && 
         !(game.player.x == nx && game.player.y == ny));
      if (!ok)
        {
          changeRandomDirection();
          return;
        }
      else setPosition(nx, ny);
    }


// logic: run away from this x,y
  function logicRunAwayFrom(xx: Int, yy: Int)
    {
      // form a temp list of dirs that have empty tiles and are as far away
      // from threat as possible
      var tmp = [];
      for (i in 0...Const.dirx.length)
        {
          var nx = x + Const.dirx[i];
          var ny = y + Const.diry[i];
          var ok = (
            game.area.isWalkable(nx, ny) && !game.area.hasAI(nx, ny) && 
              (Math.abs(nx - game.player.x) >= Math.abs(x - game.player.x) &&
               Math.abs(ny - game.player.y) >= Math.abs(y - game.player.y))
            );
          if (ok)
            tmp.push(i);
        }

      // nowhere to run
      if (tmp.length == 0)
        {
          Const.todo('is in panic and has nowhere to run!');
          return;
        }

      direction = tmp[Std.random(tmp.length)];
//      trace('tmp: ' + tmp + ' ai at (' + x + ',' + y + '): dir: ' + direction +
//        ' n:' + (x + Const.dirx[direction]) + ',' + (y + Const.diry[direction]));

//      var distSqr = Const.getDistSquared(x, y, xx, yy);
      var nx = x + Const.dirx[direction];
      var ny = y + Const.diry[direction];
      setPosition(nx, ny);
    }


// logic: try to tear parasite away
  function logicTearParasiteAway()
    {
      log('tries to tear you away!');

      game.player.attachHold -= strength;
      if (game.player.attachHold > 0)
        return;

      parasiteAttached = false;
      log('manages to tear you away.'); 
      game.player.onDetach(); // notify player
    }


// logic: attack player
  function logicAttack()
    {
      // search for player
      if (!seesPosition(game.player.x, game.player.y))
        {
          logicRoam();
          return;
        }

      // attack the threat

      // get current weapon
      var item = inventory.getFirstWeapon();
      var info = null;

      // use fists
      if (item == null)
        info = ConstItems.fists;
      else info = item.info;

      // weapon skill level
      var skillLevel = skills.getLevel(info.weaponStats.skill);

      // roll skill
      if (Std.random(100) > skillLevel)
        {
          log('tries to ' + info.verb1 + ' you, but misses.');
          return;
        }

      // success, roll damage
      var damage = Const.roll(info.weaponStats.minDamage, info.weaponStats.maxDamage);
      if (!info.weaponStats.isRanged) // all melee weapons have damage bonus
        damage += Const.roll(0, Std.int(strength / 2));

      log(info.verb2 + ' ' + 
        (game.player.state == Player.STATE_HOST ? 'your host' : 'you') + 
        ' for ' + damage + ' damage.');

      game.player.onDamage(damage);
    }


// ===================================  STATE  =======================================


// state: default idle state handling
  function stateIdle()
    {
      // alertness update
      if (seesPosition(game.player.x, game.player.y))
        {
          var distance = Const.getDist(x, y, game.player.x, game.player.y);
          alertness += 3 * (Const.AI_VIEW_DISTANCE + 1 - distance);
        }
      else alertness -= 5;

      // AI has become alerted
      if (alertness >= 100)
        {
          setState(STATE_ALERT, REASON_PARASITE);
          return;
        }

      // stand and wonder what happened until alertness go down
      if (alertness > 0)
        return;

      // TODO: i could make hooks here, leaving the alert logic intact

      // roam by default
      logicRoam();
    }


// state: default alert state handling
  function stateAlert()
    {
      // alerted timer update
      if (seesPosition(game.player.x, game.player.y))
        alertTimer = Const.AI_ALERTED_TIMER;
      else alertTimer--;
  
      // AI calms down
      if (alertTimer == 0)
        {
          state = STATE_IDLE;
          alertness = 90;
          return;
        }

      // parasite attached - try to tear it away
      if (parasiteAttached)
        logicTearParasiteAway();
      
      // call alert logic for this AI type
      else
        {
          // aggressive AI - attack player if he is near
          if (isAggressive)
            logicAttack();

          // not aggressive AI - try to run away
          else logicRunAwayFrom(game.player.x, game.player.y);
        }
    }


// state: host logic
  function stateHost()
    {
      // random: try to tear parasite away
      if (game.player.hostControl < 25 && Std.random(100) < 5)
        {
          log('manages to tear you away.');
          onDetach();
          game.player.onDetach(); // notify player
        }
    }


// call AI logic
  public function ai()
    {
      if (state == STATE_IDLE)
        stateIdle();

      // AI alerted - try to run away or attack
      else if (state == STATE_ALERT)
        stateAlert();

      // controlled by parasite
      else if (state == STATE_HOST)
        stateHost();

      // clamp and change entity icons
      updateEntity();
    }


// ================================ EVENTS =========================================


// event: AI receives damage
  public function onDamage(damage: Int)
    {
      health -= damage;
      if (health == 0)
        setState(STATE_DEAD);
    }


// event: parasite attached to this host
  public inline function onAttach()
    {
      // set AI state
      parasiteAttached = true;
      setState(STATE_ALERT, REASON_ATTACH);
    }


// event: parasite invaded this host
  public inline function onInvade()
    {
      setState(STATE_HOST);
      parasiteAttached = false;
      entity.setMask(Const.FRAME_MASK_POSSESSED);
    }


// event: parasite detach from this host
  public inline function onDetach()
    {
      setState(STATE_ALERT, REASON_DETACH);
      entity.setMask(Const.FRAME_EMPTY);
    }


// event dynamic: on state change
  public dynamic function onStateChange()
    {}


// =================================================================================


// log
  public inline function log(s: String)
    {
      game.log(name + ' ' + s);
    }


// ========================== SETTERS ====================================

  function set_health(v: Int)
    { return health = Const.clamp(v, 0, maxHealth); }
  function set_alertness(v: Int)
    { return alertness = Const.clamp(v, 0, 100); }


// =================================================================================

  // AI states
  public static var STATE_IDLE = 'idle';
  public static var STATE_ALERT = 'alert';
  public static var STATE_HOST = 'host';
  public static var STATE_DEAD = 'dead';

  // AI state change reasons
  public static var REASON_NONE = 'none';
  public static var REASON_ATTACH = 'attach';
  public static var REASON_DETACH = 'detach';
  public static var REASON_PARASITE = 'parasite';
}
