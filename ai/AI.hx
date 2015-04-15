// NPC AI game state

package ai;

import entities.AIEntity;
import _AIState;
import objects.*;
import game.*;
import const.EvolutionConst;
import const.ItemsConst;

class AI
{
  var game: Game; // game state link
  public var entity: AIEntity; // gui entity
  public var event: scenario.Event; // event link (for scenario npcs)
  public var npc: scenario.NPC; // npc link (for scenario npcs)

  public var type: String; // ai type
  public var job: String; // ai job 
  public var name: 
    { 
      real: String, // real name
      realCapped: String, // capitalized real name
      unknown: String, // class name
      unknownCapped: String // class name capitalized
    }; // AI name (can be unique and capitalized)
  var sounds: Map<String, Array<AISound>>; // map of sounds generated by AI

  public var isAggressive: Bool; // true - attack in alerted state, false - run away
  public var isNameKnown: Bool; // is real name known to player?
  public var isJobKnown: Bool; // is job known to player?
  public var isHuman: Bool; // is it a human?
  public var isCommon: Bool; // is it common AI or spawned by area alertness logic?

  public var id: Int; // unique AI id
  static var _maxID: Int = 0; // current max ID
  public var x: Int; // grid x,y
  public var y: Int;
  var direction: Int; // direction of movement

  var _objectsSeen: List<Int>; // list of object IDs this AI has seen
  var _turnsInvisible: Int; // number of turns passed since player saw this AI

  public var state: _AIState; // AI state
  public var reason: _AIStateChangeReason; // reason for setting this state 
  public var alertness(default, set): Int; // 0-100, how alert is AI to the parasite

  // various AI timers
  public var timers: {
    alert: Int, // alerted, count down until AI calms down

    // alerted and player not visible, count down
//    alertPlayerNotVisible: Int,
    };

  // attrs 
  public var baseAttrs: _Attributes; // base attributes
  public var modAttrs: _Attributes; // attribute mods
  public var strength(get, set): Int; // physical strength (1-10)
  public var constitution(get, set): Int; // physical constitution (1-10)
  public var intellect(get, set): Int; // mental capability (1-10)
  public var psyche(get, set): Int; // mental strength (1-10)
  public var _strength: Int; // current values
  public var _constitution: Int;
  public var _intellect: Int;
  public var _psyche: Int;

  // stats
  public var health(default, set): Int; // current health
  public var maxHealth: Int; // maximum health
  public var energy(default, set): Int; // amount of turns until host death
  public var maxEnergy: Int; // max amount of turns until host death
  public var brainProbed: Int; // how many times brain was probed

  public var inventory: Inventory; // AI inventory
  public var skills: Skills; // AI skills
  public var organs: Organs; // AI organs
  public var effects: Effects; // AI effects

  // state vars
  public var parasiteAttached: Bool; // is parasite currently attached to this AI

  public function new(g: Game, vx: Int, vy: Int)
    {
      game = g;
      type = 'undefined';
      job = 'undefined';
      name =
        {
          real: 'undefined',
          realCapped: 'undefined',
          unknown: 'undefined',
          unknownCapped: 'undefined'
        };
      sounds = new Map<String, Array<AISound>>();

      id = (_maxID++);
      x = vx;
      y = vy;

      state = AI_STATE_IDLE;
      reason = REASON_NONE;
      alertness = 0;
      brainProbed = 0;
      timers = 
        {
          alert: 0,
//          alertPlayerNotVisible: 0
        };

      direction = 0;
      isAggressive = false;
      isCommon = true;
      isNameKnown = false;
      isJobKnown = false;
      isHuman = false;
      parasiteAttached = false;
      baseAttrs = {
        strength: 1,
        constitution: 1,
        intellect: 1,
        psyche: 1
        };
      modAttrs = {
        strength: 0,
        constitution: 0,
        intellect: 0,
        psyche: 0
        };
      _strength = 0;
      _constitution = 0;
      _intellect = 0;
      _psyche = 0;
      maxHealth = 1;
      health = 1;
      energy = 10;
      maxEnergy = 10;
      _objectsSeen = new List<Int>();
      _turnsInvisible = 0;

      inventory = new Inventory(game);
      skills = new Skills(game, false);
      organs = new Organs(game, this);
      effects = new Effects(game, this);
    }


// save derived stats (must be called in the end of derived classes constructors)
  function derivedStats()
    {
      recalc();
      energy = maxEnergy;
      health = maxHealth;
    }


// recalculate all stat bonuses
  public function recalc()
    {
      // clean mods
      modAttrs.strength = 0;
      modAttrs.constitution = 0;
      modAttrs.intellect = 0;
      modAttrs.psyche = 0;
  
      // organ: muscle enhancement
      var o = organs.get(IMP_MUSCLE);
      if (o != null)
        modAttrs.strength += o.params.strength;

      _strength = baseAttrs.strength + modAttrs.strength;
      _constitution = baseAttrs.constitution + modAttrs.constitution;
      _intellect = baseAttrs.intellect + modAttrs.intellect;
      _psyche = baseAttrs.psyche + modAttrs.psyche;
  
      // organ: host energy bonus
      var o = organs.get(IMP_ENERGY);
      var energyMod = 1.0;
      if (o != null)
        energyMod = o.params.hostEnergyMod;

      maxEnergy = Std.int((5 + strength + constitution) * 10 * energyMod);
      maxHealth = strength + constitution;
  
      // organ: health increase 
      var o = organs.get(IMP_HEALTH);
      if (o != null)
        maxHealth += o.params.health;
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
  public function setState(vstate: _AIState, ?vreason: _AIStateChangeReason)
    {
      if (vreason == null)
        vreason = REASON_NONE;

      // AI is already in that state
      if (state == vstate)
        return;

      state = vstate;
      reason = vreason;
      if (state == AI_STATE_ALERT)
        timers.alert = ALERTED_TIMER;

      onStateChange(); // dynamic event
      updateEntity(); // update icon
    }


// post alert changes, clamp and change icon
  public function updateEntity()
    {
      var alertFrame = Const.FRAME_EMPTY;
      if (state == AI_STATE_ALERT)
        alertFrame = Const.FRAME_ALERTED;
      else if (state == AI_STATE_IDLE)
        {
          if (alertness > 75)
            alertFrame = Const.FRAME_ALERT3;
          else if (alertness > 50)
            alertFrame = Const.FRAME_ALERT2;
          else if (alertness > 0)
            alertFrame = Const.FRAME_ALERT1;
        }

      // panic state
      if (effects.has(EFFECT_PANIC))
        alertFrame = Const.FRAME_PANIC;

      // paralysis state
      if (effects.has(EFFECT_PARALYSIS))
        alertFrame = Const.FRAME_PARALYSIS;

      entity.setAlert(alertFrame);
    }


// ===================================  LOGIC  =======================================


// logic: roam around (default)
  public function logicRoam()
    {
      if (Math.random() < 0.2)
        changeRandomDirection();

      // nowhere to move - should be a bug
      if (direction == -1)
        return;

      var nx = x + Const.dirx[direction];
      var ny = y + Const.diry[direction];
      var ok = 
        (game.area.isWalkable(nx, ny) && 
         !game.area.hasAI(nx, ny) && 
         !(game.playerArea.x == nx && game.playerArea.y == ny));
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
              (Math.abs(nx - game.playerArea.x) >= Math.abs(x - game.playerArea.x) &&
               Math.abs(ny - game.playerArea.y) >= Math.abs(y - game.playerArea.y))
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

      game.playerArea.attachHold -= strength;
      if (game.playerArea.attachHold > 0)
        return;

      parasiteAttached = false;
      log('manages to tear you away.'); 
      game.playerArea.onDetach(); // notify player
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
        info = ItemsConst.fists;
      else info = item.info;

      // check for distance on melee
      if (!info.weaponStats.isRanged && !isNear(game.playerArea.x, game.playerArea.y))
        {
          logicMoveTo(game.playerArea.x, game.playerArea.y);
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
      var tmp: Array<Int> = [];
      var damage = Const.roll(info.weaponStats.minDamage, info.weaponStats.maxDamage);
      tmp.push(damage);
      if (!info.weaponStats.isRanged) // all melee weapons have damage bonus
        {
          var bonus = Const.roll(0, Std.int(strength / 2));
          damage += bonus;
          tmp.push(bonus);
        }

      // protective cover
      if (game.player.state == PLR_STATE_HOST)
        {
          var o = organs.get(IMP_PROT_COVER);
          if (o != null)
            {
              damage -= Std.int(o.params.armor);
              tmp.push(- Std.int(o.params.armor));
            }
        }
      if (damage < 0)
        damage = 0;

      log(info.verb2 + ' ' + 
        (game.player.state == PLR_STATE_HOST ? 'your host' : 'you') + 
        ' for ' + damage + ' damage.');
#if mydebug
      game.log('AI.attack: ' + tmp);
#end

      game.playerArea.onDamage(damage); // on damage event
    }


// ===================================  LOGIC =======================================


// state: default idle state handling
  function stateIdle()
    {
      // alertness update
      if (!game.player.vars.invisibilityEnabled &&
          seesPosition(game.playerArea.x, game.playerArea.y))
        {
          var distance = Const.getDist(x, y, game.playerArea.x, game.playerArea.y);

          var baseAlertness = 3;
          var alertnessBonus = 0;

          // if player is on a host, check for organs
          if (game.player.state == PLR_STATE_HOST)
            {
              // organ: camouflage layer
              var params = EvolutionConst.getParams(IMP_CAMO_LAYER, 0);
              var o = organs.get(IMP_CAMO_LAYER);
              if (o != null)
                baseAlertness = o.params.alertness;
              else baseAlertness = params.alertness;

              // organ: protective cover
              var params = EvolutionConst.getParams(IMP_PROT_COVER, 0);
              var o = organs.get(IMP_PROT_COVER);
              if (o != null)
                alertnessBonus += o.params.alertness;
              else alertnessBonus += params.alertness;
            }
          alertness += Std.int(baseAlertness * (VIEW_DISTANCE + 1 - distance));
        }
      else alertness -= 5;

      // AI has become alerted
      if (alertness >= 100)
        {
          setState(AI_STATE_ALERT, 
            (game.player.state == PLR_STATE_PARASITE ? REASON_PARASITE : REASON_HOST));
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
      if (!game.player.vars.invisibilityEnabled &&
          seesPosition(game.playerArea.x, game.playerArea.y))
        timers.alert = ALERTED_TIMER;
      else timers.alert--;
  
      // AI calms down
      if (timers.alert == 0)
        {
          setState(AI_STATE_IDLE); 
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
              if (!game.player.vars.invisibilityEnabled)
                {
                  // search for player
                  // we cheat a little and follow invisible player 
                  // before alert timer ends 
                  if (!seesPosition(game.playerArea.x, game.playerArea.y))
                    logicMoveTo(game.playerArea.x, game.playerArea.y);

                  // try to attack
                  else logicAttack();
                }
            }

          // not aggressive AI - try to run away
          else logicRunAwayFrom(game.playerArea.x, game.playerArea.y);
        }
    }


// state: host logic
  function stateHost()
    {
      // emit random sound
      emitRandomSound('' + AI_STATE_HOST, Std.int((100 - game.player.hostControl) / 3));

      // random: try to tear parasite away
      if (game.player.hostControl < 25 && Std.random(100) < 5)
        {
          log('manages to tear you away.');
          onDetach();
          game.playerArea.onDetach(); // notify player
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
            setState(AI_STATE_ALERT, REASON_BODY);

          _objectsSeen.add(obj.id);
        }
    }


// checks if this AI should be despawned
// AI despawns when player has not seen it for X turns in a row and its state is idle
  public function checkDespawn()
    {
      // should be in idle state and calmed down
      if (state != AI_STATE_IDLE || (state == AI_STATE_IDLE && alertness > 25))
        {
          _turnsInvisible = 0;
          return;
        }

      // should be invisible to player
      var isVisible = game.area.isVisible(game.playerArea.x, game.playerArea.y, x, y);
      if (isVisible)
        {
          _turnsInvisible = 0;
          return;
        }

      _turnsInvisible++;
      if (_turnsInvisible > DESPAWN_TIMER)
        game.area.removeAI(this); 
    }


// logic: slime
  function effectSlime()
    {
      var free = effects.decrease(EFFECT_SLIME, strength);
      if (free)
        log('manages to get free of the slime.');
      else log('desperately tries to get free of the slime.');

      // set alerted state
      if (state == AI_STATE_IDLE)
        setState(AI_STATE_ALERT, REASON_DAMAGE);

      emitRandomSound('' + REASON_DAMAGE, 30); // emit random sound
    }


// call AI logic
  public function turn()
    {
      entity.turn(); // time passing for entity
      effects.turn(1); // time passing for effects

      // effect: slime, does not allow movement
      if (effects.has(EFFECT_SLIME))
        effectSlime();

      // effect: paralysis 
      else if (effects.has(EFFECT_PARALYSIS))
        1;

      // effect: panic, run away 
      else if (effects.has(EFFECT_PANIC))
        logicRunAwayFrom(game.playerArea.x, game.playerArea.y);

      else if (state == AI_STATE_IDLE)
        stateIdle();

      // AI alerted - try to run away or attack
      else if (state == AI_STATE_ALERT)
        stateAlert();

      // controlled by parasite
      else if (state == AI_STATE_HOST)
        stateHost();

      updateEntity(); // clamp and change entity icons
      checkDespawn(); // check for this AI to despawn
      emitRandomSound('' + state, 20); // emit random sound if it exists
    }


// emit random sound for this key 
  function emitRandomSound(key: String, ?chance: Int = 100)
    {
      var array = sounds[key];
      if (array == null)
        return;

      if (Std.random(100) > chance) // base chance of emitting sound
        return;

      var idx = Std.random(array.length);
      var sound = array[idx];

      // check for min alertness
      if (state == AI_STATE_IDLE && sound.params.minAlertness != null &&
          alertness < sound.params.minAlertness)
        return;

      entity.setText(sound.text, 2);
      if (sound.radius <= 0 || sound.alertness <= 0)
        return;

      // get a list of AIs in that radius without los checks and give alertness bonus
      var list = game.area.getAIinRadius(x, y, sound.radius, false);
      for (ai in list)
        if (ai.state == AI_STATE_IDLE) 
          ai.alertness += sound.alertness;
    }

// ================================ EVENTS =========================================


// event: AI receives damage
  public function onDamage(damage: Int)
    {
      organs.onDamage(damage); // propagate event to organs
      health -= damage;
      if (health == 0) // AI death
        {
          setState(AI_STATE_DEAD);
          onDeath();

          return;
        }

      // set alerted state
      if (state == AI_STATE_IDLE)
        setState(AI_STATE_ALERT, REASON_DAMAGE);

      emitRandomSound('' + REASON_DAMAGE, 30); // emit random sound
    }


// event: on death
  public function onDeath()
    {
      game.area.removeAI(this);
      var o = new BodyObject(game, x, y, type);

      // decay acceleration
      var organ = organs.getActive(IMP_DECAY_ACCEL);
      if (organ != null)
        o.setDecay(organ.params.turns);

      o.isHumanBody = isHuman;
      o.organPoints = organs.getPoints();
      o.inventory = inventory; // copy inventory
      game.area.updateVisibility();
    }


// event: parasite attached to this host
  public inline function onAttach()
    {
      // set AI state
      parasiteAttached = true;
      setState(AI_STATE_ALERT, REASON_ATTACH);
    }


// event: parasite invaded this host
  public inline function onInvade()
    {
      setState(AI_STATE_HOST);
      parasiteAttached = false;
      entity.setMask(Const.FRAME_MASK_POSSESSED);
    }


// event: parasite detach from this host
  public inline function onDetach()
    {
      setState(AI_STATE_ALERT, REASON_DETACH);
      entity.setMask(Const.FRAME_EMPTY);
    }


// event: on receiving effect
  public inline function onEffect(effect: _AIEffect)
    {
      effects.add(effect);

      updateEntity(); // update entity graphics
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
  function set_energy(v: Int)
    { return energy = Const.clamp(v, 0, maxEnergy); }
  function set_alertness(v: Int)
    { return alertness = Const.clamp(v, 0, 100); }

  function get_strength()
    { return _strength; }
  function set_strength(v: Int)
    { return baseAttrs.strength = v; }
  function get_constitution()
    { return _constitution; }
  function set_constitution(v: Int)
    { return baseAttrs.constitution = v; }
  function get_intellect()
    { return _intellect; }
  function set_intellect(v: Int)
    { return baseAttrs.intellect = v; }
  function get_psyche()
    { return _psyche; }
  function set_psyche(v: Int)
    { return baseAttrs.psyche = v; }

// =================================================================================
  // AI view and hear distance
  public static var VIEW_DISTANCE = 10;
  public static var HEAR_DISTANCE = 15;

  // number of turns AI stays alerted
  public static var ALERTED_TIMER = 10;

  // number of turns AI will stay spawned when invisible to player
  public static var DESPAWN_TIMER = 5;
}


// valid reasons for AI to change state

enum _AIStateChangeReason
{
  REASON_NONE;
  REASON_BODY;
  REASON_BACKUP;
  REASON_ATTACH;
  REASON_DETACH;
  REASON_HOST;
  REASON_PARASITE;
  REASON_DAMAGE;
  REASON_WITNESS;
}


// AI bark with parameters

typedef AISound =
{
  var text: String; // text to display
  var radius: Int; // radius this sound propagates to (can be 0)
  var alertness: Int; // amount of alertness that AIs in this radius gain
  var params: Dynamic; // state-specific parameters
};

