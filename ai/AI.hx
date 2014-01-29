// NPC AI game state

package ai;

import entities.AIEntity;

class AI
{
  var game: Game; // game state link

  public var entity: AIEntity; // gui entity
  public var type: String; // object type
  var name: 
    { 
      real: String, // real name
      realCapped: String, // capitalized real name
      unknown: String, // class name
      unknownCapped: String // class name capitalized
    }; // AI name (can be unique and capitalized)

  public var isAggressive: Bool; // true - attack in alerted state, false - run away
  public var isNameKnown: Bool; // is real name known to player?
  public var isHuman: Bool; // is it a human?

  public var id: Int; // unique AI id
  static var _maxID: Int = 0; // current max ID
  public var x: Int; // grid x,y
  public var y: Int;
  var direction: Int; // direction of movement

  var _objectsSeen: List<Int>; // list of object IDs this AI has seen
  var _turnsInvisible: Int; // number of turns passed since player saw this AI

  public var state: String; // AI state
  public var reason: String; // reason for setting this state 
  public var alertness(default, set): Int; // 0-100, how alert is AI to the parasite

  // various AI timers
  public var timers: {
    alert: Int, // alerted, count down until AI calms down

    // alerted and player not visible, count down
//    alertPlayerNotVisible: Int,
    };

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
  public var organs: Organs; // AI organs

  // state vars
  public var parasiteAttached: Bool; // is parasite currently attached to this AI

  public function new(g: Game, vx: Int, vy: Int)
    {
      game = g;
      type = 'undefined';
      name =
        {
          real: 'undefined',
          realCapped: 'undefined',
          unknown: 'undefined',
          unknownCapped: 'undefined'
        };

      id = (_maxID++);
      x = vx;
      y = vy;

      state = STATE_IDLE;
      reason = REASON_NONE;
      alertness = 0;
      timers = 
        {
          alert: 0,
//          alertPlayerNotVisible: 0
        };

      direction = 0;
      isAggressive = false;
      isNameKnown = false;
      isHuman = false;
      parasiteAttached = false;
      strength = 1;
      constitution = 1;
      intellect = 1;
      psyche = 1;
      maxHealth = 1;
      health = 1;
      hostExpiryTurns = 10;
      _objectsSeen = new List<Int>();
      _turnsInvisible = 0;

      inventory = new Inventory();
      skills = new Skills();
      organs = new Organs(game, this);
    }


// save derived stats (must be called in the end of derived classes constructors)
  function derivedStats()
    {
      hostExpiryTurns = (5 + strength + constitution) * 10;
//      maxHealth = Std.int(strength / 2) + constitution;
      maxHealth = strength + constitution;
      health = maxHealth;
    }


// get name depending on whether its known or not
  public inline function getName(): String
    {
      return (isNameKnown ? name.real : name.unknown);
    }


// get capped name depending on whether its known or not
  public inline function getNameCapped(): String
    {
      return (isNameKnown ? name.realCapped : name.unknownCapped);
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

      updateEntity(); // update icon
    }


// set position
  public function setPosition(vx: Int, vy: Int)
    {
      x = vx;
      y = vy;
      entity.setPosition(x, y);
    }


// internal: change direction at random to the empty space
  inline function changeRandomDirection()
    {
      direction = game.area.getRandomDirection(x, y);
      if (direction == -1)
        trace('ai at (' + x + ',' + y + '): nowhere to move!');
    }


// does this AI sees this position?
  function seesPosition(xx: Int, yy: Int): Bool
    {
      // too far away
      var distSqr = Const.getDistSquared(x, y, xx, yy);
      if (distSqr > VIEW_DISTANCE * VIEW_DISTANCE)
        return false;

      // check for visibility
      if (!game.area.isVisible(x, y, xx, yy))
        return false;

      return true;
    }


// is this AI near that spot?
  public inline function isNear(xx: Int, yy: Int): Bool
    {
      return (Math.abs(xx - x) <= 1 && Math.abs(yy - y) <= 1);
    }


// set AI state (plus all vars for this state)
  public function setState(vstate: String, ?vreason: String = 'none')
    {
      // AI is already in that state
      if (state == vstate)
        return;

      state = vstate;
      reason = vreason;
      if (state == STATE_ALERT)
        timers.alert = ALERTED_TIMER;

      onStateChange(); // dynamic event
      updateEntity(); // update icon
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


// logic: move to x,y
  function logicMoveTo(x2: Int, y2: Int)
    {
      // get path
      var path = game.area.getPath(x, y, x2, y2);
      if (path == null)
        return;

      setPosition(path[0].x, path[0].y);
    }


// logic: attack player
  function logicAttack()
    {
      // get current weapon
      var item = inventory.getFirstWeapon();
      var info = null;

      // use fists
      if (item == null)
        info = ConstItems.fists;
      else info = item.info;

      // check for distance on melee
      if (!info.weaponStats.isRanged && !isNear(game.player.x, game.player.y))
        {
          logicMoveTo(game.player.x, game.player.y);
          return;
        }

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

      game.player.onDamage(damage); // on damage event
    }


// ===================================  STATE  =======================================


// state: default idle state handling
  function stateIdle()
    {
      // alertness update
      if (seesPosition(game.player.x, game.player.y))
        {
          var distance = Const.getDist(x, y, game.player.x, game.player.y);

          // check if player is on a host and has active camouflage layer
          var hasCamo = (game.player.state == Player.STATE_HOST ? 
            game.player.host.organs.has('camouflageLayer') : false);
          var baseAlertness = 3;
          if (hasCamo)
            {
              var params = game.player.evolutionManager.getParams('camouflageLayer');
              baseAlertness = params.baseAlertness;
            }
          alertness += Std.int(baseAlertness * (VIEW_DISTANCE + 1 - distance));
        }
      else alertness -= 5;

      // AI has become alerted
      if (alertness >= 100)
        {
          setState(STATE_ALERT, 
            (game.player.state == Player.STATE_PARASITE ? REASON_PARASITE : REASON_HOST));
          return;
        }

      // AI vision
      visionIdle();

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
        timers.alert = ALERTED_TIMER;
      else timers.alert--;
  
      // AI calms down
      if (timers.alert == 0)
        {
          setState(STATE_IDLE); 
          alertness = 10;
          return;
        }

      // parasite attached - try to tear it away
      if (parasiteAttached)
        logicTearParasiteAway();
      
      // call alert logic for this AI type
      else
        {
          // aggressive AI - attack player if he is near or search for him
          if (isAggressive)
            {
              // search for player
              // we cheat a little and follow invisible player 
              // before alert timer ends 
              if (!seesPosition(game.player.x, game.player.y))
                logicMoveTo(game.player.x, game.player.y);

              // try to attack
              else logicAttack();
            }

          // not aggressive AI - try to run away
          else logicRunAwayFrom(game.player.x, game.player.y);
        }
    }


// state: host logic
  function stateHost()
    {
      // organ growth
      organs.turn();

      // random: try to tear parasite away
      if (game.player.hostControl < 25 && Std.random(100) < 5)
        {
          log('manages to tear you away.');
          onDetach();
          game.player.onDetach(); // notify player
        }
    }


// AI vision: called only in idle state
  function visionIdle()
    {
      // get all objects that this AI sees
      var tmp = game.area.getObjectsInRadius(x, y, VIEW_DISTANCE, true);

      for (obj in tmp)
        {
          // not a body
          if (obj.type != 'body')
            continue;

          // already seen
          if (Lambda.has(_objectsSeen, obj.id))
            continue;

          var body: BodyObject = untyped obj;

          // human AI becomes alert on seeing human bodies
          if (isHuman && body.isHumanBody)
            setState(AI.STATE_ALERT, AI.REASON_BODY);

          _objectsSeen.add(obj.id);
        }
    }


// checks if this AI should be despawned
// AI despawns when player has not seen it for X turns in a row and its state is idle
  public function checkDespawn()
    {
      // should be in idle state and calmed down
      if (state != STATE_IDLE || (state == STATE_IDLE && alertness > 25))
        {
          _turnsInvisible = 0;
          return;
        }

      // should be invisible to player
      var isVisible = game.area.isVisible(game.player.x, game.player.y, x, y);
      if (isVisible)
        {
          _turnsInvisible = 0;
          return;
        }

      _turnsInvisible++;
      if (_turnsInvisible > DESPAWN_TIMER)
        game.area.destroyAI(this); 
    }


// call AI logic
  public function turn()
    {
      if (state == STATE_IDLE)
        stateIdle();

      // AI alerted - try to run away or attack
      else if (state == STATE_ALERT)
        stateAlert();

      // controlled by parasite
      else if (state == STATE_HOST)
        stateHost();

      updateEntity(); // clamp and change entity icons

      checkDespawn(); // check for this AI to despawn
    }


// ================================ EVENTS =========================================


// event: AI receives damage
  public function onDamage(damage: Int)
    {
      health -= damage;
      if (health == 0) // AI death
        {
          setState(STATE_DEAD);
          onDeath();

          return;
        }

      // set alerted state
      if (state == STATE_IDLE)
        setState(STATE_ALERT, REASON_DAMAGE);
    }


// event: on death
  public function onDeath()
    {
      game.area.destroyAI(this);
      var o = new BodyObject(game, x, y, type);

      // decay acceleration
      var organ = organs.getActive('decayAccel');
      if (organ != null)
        {
          var params = ConstEvolution.getParams('decayAccel', organ.level);
          o.setDecay(params.turns);
        }

      o.isHumanBody = isHuman;
      o.organPoints = organs.getPoints();
      game.area.updateVisibility();
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
  dynamic function onStateChange()
    {}


// event dynamic: on being attacked 
  public dynamic function onAttack()
    {}


// =================================================================================


// log
  public inline function log(s: String)
    {
      game.log(getNameCapped() + ' ' + s);
    }


// ========================== SETTERS ====================================

  function set_health(v: Int)
    { return health = Const.clamp(v, 0, maxHealth); }
  function set_alertness(v: Int)
    { return alertness = Const.clamp(v, 0, 100); }


// =================================================================================
  // AI view and hear distance
  public static var VIEW_DISTANCE = 10;
  public static var HEAR_DISTANCE = 15;

  // number of turns AI stays alerted
  public static var ALERTED_TIMER = 10;

  // number of turns AI will stay spawned when invisible to player
  public static var DESPAWN_TIMER = 5;

  // AI states
  public static var STATE_IDLE = 'idle';
  public static var STATE_ALERT = 'alert';
  public static var STATE_HOST = 'host';
  public static var STATE_DEAD = 'dead';

  // AI state change reasons
  public static var REASON_NONE = 'none';
  public static var REASON_BODY = 'body';
  public static var REASON_ATTACH = 'attach';
  public static var REASON_DETACH = 'detach';
  public static var REASON_HOST = 'host';
  public static var REASON_PARASITE = 'parasite';
  public static var REASON_DAMAGE = 'damage';
  public static var REASON_WITNESS = 'witness';
}
