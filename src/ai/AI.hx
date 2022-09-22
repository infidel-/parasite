// NPC AI game state

package ai;

import h2d.Tile;
import entities.AIEntity;
import _AIState;
import objects.*;
import game.*;
import const.*;
import __Math;

class AI extends _SaveObject
{
  static var _ignoredFields = [ 'entity', 'event', 'npc', 'sounds',
  ];
  var game: Game; // game state link
  public var entity: AIEntity; // gui entity
  public var eventID: String;
  public var event(get, null): scenario.Event; // event link (for scenario npcs)
  public var npcID: Int;
  public var npc(get, null): scenario.NPC; // npc link (for scenario npcs)
  public var isNPC: Bool;
  public var tile(default, null): Tile; // AI tile
  var tileAtlasX: Int; // tile atlas info
  var tileAtlasY: Int;

  public var type: String; // ai type
  public var job: String; // ai job
  public var name: _AIName; // AI name (can be unique and capitalized)
  var soundsID: String;
  var sounds: Map<String, Array<AISound>>; // map of sounds generated by AI

  public var isMale: Bool; // gender
  public var isRelentless: Bool; // will not lose alertness once gained
  public var isAggressive: Bool; // true - attack in alerted state, false - run away
  public var isNameKnown: Bool; // is real name known to player?
  public var isJobKnown: Bool; // is job known to player?
  public var isAttrsKnown: Bool; // are attributes known to player?
  public var isHuman: Bool; // is it a human?
  public var isCommon: Bool; // is it common AI or spawned by area alertness logic?
  public var isTeamMember: Bool; // is this AI a group team member?
  public var isGuard: Bool; // is it a guard? (guards do not despawn when unseen)

  // history flags
  public var wasAttached: Bool; // was parasite attached to this AI?
  public var wasInvaded: Bool; // was this AI a host at any point?
  public var wasAlerted: Bool; // was this AI alerted at some point?
  public var wasNoticed: Bool; // was this AI seen by parasite after spawning?

  public var id: Int; // unique AI id
  public static var _maxID: Int = 0; // current max ID
  public var x: Int; // grid x,y
  public var y: Int;
  // target x,y when roaming or moving to (resets on state change)
  public var roamTargetX: Int;
  public var roamTargetY: Int;
  // guarding target (for guards)
  public var guardTargetX: Int;
  public var guardTargetY: Int;
  var direction: Int; // direction of movement

  var _objectsSeen: List<Int>; // list of object IDs this AI has seen
  var _turnsInvisible: Int; // number of turns passed since player saw this AI

  public var state: _AIState; // AI state
  public var stateTime: Int; // turns spent in this state
  public var reason: _AIStateChangeReason; // reason for setting this state
  public var alertness(default, set): Int; // 0-100, how alert is AI to the parasite

  // various AI timers
  public var timers: _AITimers;

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
  public var maxOrgans(get, null): Int; // max amount of organs
  public var maxItems(get, null): Int; // max amount of items in inventory

  public var inventory: Inventory; // AI inventory
  public var skills: Skills; // AI skills
  public var organs: Organs; // AI organs
  public var effects: Effects; // AI effects
  public var traits: List<_AITraitType>;

  // state vars
  public var parasiteAttached: Bool; // is parasite currently attached to this AI

  public function new(g: Game, vx: Int, vy: Int)
    {
      game = g;
      id = (_maxID++);
      x = vx;
      y = vy;

// will be called by sub-classes
//      init();
//      initPost(false);
    }

// init object before loading/post creation
  public function init()
    {
      tile = null;
      tileAtlasX = -1;
      tileAtlasY = -1;
      type = 'undefined';
      job = 'undefined';
      name = {
        real: 'undefined',
        realCapped: 'undefined',
        unknown: 'undefined',
        unknownCapped: 'undefined'
      };
      sounds = null;
      roamTargetX = -1;
      roamTargetY = -1;
      guardTargetX = -1;
      guardTargetY = -1;
      state = AI_STATE_IDLE;
      stateTime = 0;
      reason = REASON_NONE;
      alertness = 0;
      brainProbed = 0;
      timers = {
        alert: 0,
//          alertPlayerNotVisible: 0
      };
      direction = 0;
      parasiteAttached = false;

      isMale = false;
      isRelentless = false;
      isAggressive = false;
      isCommon = true;
      isNameKnown = false;
      isJobKnown = false;
      isAttrsKnown = false;
      isHuman = false;
      isTeamMember = false;
      isGuard = false;
      wasAttached = false;
      wasInvaded = false;
      wasAlerted = false;
      wasNoticed = false;

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
      _objectsSeen = new List();
      _turnsInvisible = 0;
      event = null;
      eventID = null;
      npc = null;
      npcID = -1;
      isNPC = false;

      inventory = new Inventory(game);
      skills = new Skills(game, false);
      organs = new Organs(game, this);
      effects = new Effects(game, this);
      traits = new List();
    }

// called after load or creation
  public function initPost(onLoad: Bool)
    {
      sounds = SoundConst.getSounds(soundsID);
      if (onLoad)
        {
          tile = game.scene.atlas.getXY(type, isMale, tileAtlasX, tileAtlasY);
          createEntity();
          if (isNPC)
            entity.setNPC();
        }
    }

// called in main post-load
  public function loadPost()
    {
      organs.loadPost();
      skills.loadPost();
      if (npc != null)
        {
          npc.ai = this;
          entity.setNPC();
        }
    }

// show AI graphics
public function show()
  {
    createEntity();
    if (isNPC)
      entity.setNPC();
  }

// hide AI graphics
  public function hide()
    {
      entity.remove();
      entity = null;
    }

// does this AI have this trait?
  public inline function hasTrait(t: _AITraitType): Bool
    {
      return (Lambda.has(traits, t));
    }


// add trait to this AI
  public function addTrait(t: _AITraitType)
    {
      if (hasTrait(t))
        return;
      traits.add(t);
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

      // clamp new health if decreased
      health = health;
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
      if (entity != null)
        {
          updateEntity();
          return;
        }
      // do not change tile on re-creation (on entering area)
      if (tile == null)
        {
          var tmp = game.scene.atlas.get(type, isMale);
          tile = tmp.tile;
          tileAtlasX = tmp.x;
          tileAtlasY = tmp.y;
        }
      entity = new AIEntity(this, game, x, y, tile);

      updateEntity(); // update icon
    }

// update AI tile to a new one
  public function updateTile(x: Int, y: Int)
    {
      tileAtlasX = x;
      tileAtlasY = y;
      tile = game.scene.atlas.getXY(type, isMale, tileAtlasX, tileAtlasY);
      entity.tile = tile;
    }


// set position
  public function setPosition(vx: Int, vy: Int, ?force: Bool = false)
    {
      if (game.area.getAI(vx, vy) != null && !force)
        return;

      if (!force && game.player.host != this)
        {
          // frob objects on this position
          var objs = game.area.getObjectsAt(vx, vy);
          for (o in objs)
            {
              // 0 - return false
              // 1 - ok, continue
              var ret = o.frob(false, this);
              if (ret == 0)
                return;
            }
        }
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
      var distSqr = Const.distanceSquared(x, y, xx, yy);
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
  public function setState(vstate: _AIState, ?vreason: _AIStateChangeReason,
      ?msg: String)
    {
      if (vreason == null)
        vreason = REASON_NONE;

      // AI is already in that state
      if (state == vstate)
        return;

//      trace('' + id + ' reason: ' + vreason + ' state:' + vstate);
      state = vstate;
      stateTime = 0;
      reason = vreason;
      if (state == AI_STATE_ALERT)
        {
          // message on first alert
          if (isHuman && vreason != REASON_ATTACH)
            game.goals.complete(GOAL_TUTORIAL_ALERT);

          // clear path
          if (isHuman)
            game.scene.clearPath();

          timers.alert = ALERTED_TIMER;
          wasAlerted = true;
        }
      // reset roam target on going back to idle
      else if (state == AI_STATE_IDLE)
        {
          roamTargetX = -1;
          roamTargetY = -1;
        }

      if (msg != null)
        log(msg);

      onStateChange(); // dynamic event
      if (entity != null) // could despawn in state change hook
        updateEntity(); // update icon
    }


// post alert changes, clamp and change icon
  public function updateEntity()
    {
      // already despawned
      if (entity == null)
        return;

      var alertFrame = Const.FRAME_EMPTY;
      if (state == AI_STATE_ALERT)
        alertFrame = Const.FRAME_ALERTED;
      else if (state == AI_STATE_IDLE || state == AI_STATE_MOVE_TARGET)
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

      // calling
      if (game.managerArea.hasAI(this, AREAEVENT_CALL_LAW) ||
          game.managerArea.hasAI(this, AREAEVENT_CALL_BACKUP) ||
          game.managerArea.hasAI(this, AREAEVENT_CALL_TEAM_BACKUP))
        alertFrame = Const.FRAME_CALLING;

      // paralysis state
      if (effects.has(EFFECT_PARALYSIS))
        alertFrame = Const.FRAME_PARALYSIS;
      else if (effects.has(EFFECT_SLIME))
        alertFrame = Const.FRAME_SLIME;

      entity.setAlert(alertFrame);
    }


// ===================================  LOGIC  =======================================


// logic: roam around (default)
  function logicRoam()
    {
      // roam target set, move to it
      if (roamTargetX >= 0 && roamTargetY >= 0)
        {
          logicMoveTo(roamTargetX, roamTargetY);
          return;
        }

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
          if (Std.random(100) < 30)
            log('cowers in panic!');
          return;
        }

      direction = tmp[Std.random(tmp.length)];
//      trace('tmp: ' + tmp + ' ai at (' + x + ',' + y + '): dir: ' + direction +
//        ' n:' + (x + Const.dirx[direction]) + ',' + (y + Const.diry[direction]));

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
      entity.setMask(null);
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

      // use animal attack
      if (!isHuman)
        info = ItemsConst.animal;
      // use fists
      else if (item == null)
        info = ItemsConst.fists;
      else info = item.info;
      var weapon = info.weapon;

      // check for distance on melee
      if (!weapon.isRanged && !isNear(game.playerArea.x, game.playerArea.y))
        {
          logicMoveTo(game.playerArea.x, game.playerArea.y);
          return;
        }

      // parasite attached to human, do not shoot (blackops are fine)
      if (isHuman && game.player.state == PLR_STATE_ATTACHED &&
          game.playerArea.attachHost.isHuman &&
          type != 'blackops')
        {
          if (Std.random(100) < 30)
            {
              log('hesitates to attack you.');
              emitSound({ text: 'Shit!', radius: 5, alertness: 10 });
              return;
            }
        }

      // play weapon sound
      if (weapon.sound != null)
        emitSound(weapon.sound);

      // weapon skill level (ai + parasite bonus)
      var roll = __Math.skill({
        id: weapon.skill,
        // hardcoded animal attack skill level
        level: skills.getLevel(weapon.skill),
      });

      // roll skill
      if (!roll)
        {
          log('tries to ' + weapon.verb1 + ' you, but misses.');
          return;
        }

      // stun damage
      // when player has a host, stuns the host
      // when player is a parasite, just do regular damage
      if (weapon.type == WEAPON_STUN && game.player.state == PLR_STATE_HOST)
        {
          var mods: Array<_DamageBonus> = [];

          // protective cover
          if (game.player.state == PLR_STATE_HOST)
            {
              var o = game.player.host.organs.get(IMP_PROT_COVER);
              if (o != null)
                mods.push({
                  name: 'protective cover',
                  val: - Std.int(o.params.armor)
                });
            }

          var roll = __Math.damage({
            name: 'STUN AI->player',
            min: weapon.minDamage,
            max: weapon.maxDamage,
            mods: mods
          });

          var resist = __Math.opposingAttr(
            game.player.host.constitution, roll, 'con/stun');
          if (resist)
            roll = Std.int(roll / 2);
          if (game.config.extendedInfo)
            game.info('stun for ' + roll + ' rounds, -' + (roll * 2) +
              ' control.');
          game.player.hostControl -= roll * 2;

          log(weapon.verb2 + ' your host for ' + roll +
            " rounds. You're losing control.");

          game.player.host.onEffect({
            type: EFFECT_PARALYSIS,
            points: roll,
            isTimer: true
          });

          game.playerArea.onDamage(0); // on damage event
        }

      // normal damage
      else
        {
          var mods: Array<_DamageBonus> = [];
          // all melee weapons have damage bonus
          if (!weapon.isRanged && weapon.type == WEAPON_BLUNT)
            mods.push({
              name: 'melee 0.5xSTR',
              min: 0,
              max: Std.int(strength / 2)
            });

          // protective cover
          if (game.player.state == PLR_STATE_HOST)
            {
              var o = game.player.host.organs.get(IMP_PROT_COVER);
              if (o != null)
                mods.push({
                  name: 'protective cover',
                  val: - Std.int(o.params.armor)
                });

              // armor
              var clothing = game.player.host.inventory.clothing.info;
              if (clothing.armor.damage != 0)
                mods.push({
                  name: clothing.name,
                  val: - clothing.armor.damage
                });
            }

          var damage = __Math.damage({
            name: 'AI->player',
            min: weapon.minDamage,
            max: weapon.maxDamage,
            mods: mods
          });

          log(weapon.verb2 + ' ' +
            (game.player.state == PLR_STATE_HOST ? 'your host' : 'you') +
            ' for ' + damage + ' damage.');

          game.playerArea.onDamage(damage); // on damage event
        }
    }


// ===============================  LOGIC =============================


// state: default idle state handling
  function stateIdle()
    {
      // AI vision
      visionIdle();

      // stand and wonder what happened until alertness go down
      // if roam target is set, continue moving instead
      if (alertness > 0 && roamTargetX < 0)
        return;

      // TODO: i could make hooks here, leaving the alert logic intact

      // guards stand on one spot
      // someday there might even be patrollers...
      if (isGuard)
        1;
      // roam by default
      else logicRoam();
    }

// state: move to target spot
  function stateMoveTarget()
    {
      // basic AI vision
      visionIdle();

      // stand and wonder what happened until alertness goes down
      if (alertness > 0)
        return;

      logicMoveTo(roamTargetX, roamTargetY);
      if (x != roamTargetX || y != roamTargetY)
        return;
      // spot reached, idling
      roamTargetY = -1;
      roamTargetY = -1;
      setState(AI_STATE_IDLE);
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
      // relentless AI cannot calm down once alerted
      if (timers.alert == 0 && !isRelentless)
        {
          // guard must return to guard spot
          if (isGuard && (x != guardTargetX || y != guardTargetY))
            {
              setState(AI_STATE_MOVE_TARGET);
              roamTargetX = guardTargetX;
              roamTargetY = guardTargetY;
            }
          // otherwise become idle
          else setState(AI_STATE_IDLE);
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
      // non-assimilated hosts emit random sounds
      if (!hasTrait(TRAIT_ASSIMILATED))
        emitRandomSound('' + AI_STATE_HOST,
          Std.int((100 - game.player.hostControl) / 3));

      // effect: cannot tear parasite away (given right after invasion)
      if (effects.has(EFFECT_CANNOT_TEAR_AWAY))
        return;

      // random: try to tear parasite away
      if (game.player.hostControl < 25 && Std.random(100) < 5)
        {
          log('manages to tear you away.');
          onDetach('default');
          game.playerArea.onDetach(); // notify player
        }
    }


// AI vision: called in idle and movement to target states
  function visionIdle()
    {
      // player visibility
      if (!game.player.vars.invisibilityEnabled &&
          seesPosition(game.playerArea.x, game.playerArea.y))
        {
          var distance = game.playerArea.distance(x, y);
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
          alertness += Std.int(baseAlertness * (VIEW_DISTANCE + 1 - distance)) +
            alertnessBonus;
          game.profile.addPediaArticle('npcAlertness');
        }
      else alertness -= 5;

      // AI has become alerted
      if (alertness >= 100)
        {
          var reason = REASON_PARASITE;

          if (game.player.state == PLR_STATE_HOST &&
              game.player.host.isHuman)
            reason = REASON_HOST;

          setState(AI_STATE_ALERT, reason);
          return;
        }

      // get all objects that this AI sees
      var tmp = game.area.getObjectsInRadius(x, y, VIEW_DISTANCE, true);

      for (obj in tmp)
        {
          // not a body
          if (obj.type != 'body')
            continue;

          // object already seen by this AI
          if (Lambda.has(_objectsSeen, obj.id))
            continue;

          var body: BodyObject = cast obj;

          // human AI becomes alert on seeing human bodies
          if (isHuman && body.isHumanBody)
            {
              if (!body.wasSeen)
                {
                  // mark body as seen by someone to limit the law response
                  body.wasSeen = true;

                  setState(AI_STATE_ALERT, REASON_BODY);
                }

              // silent alert - no calling law
              else setState(AI_STATE_ALERT, REASON_BODY_SILENT);
            }

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

      // remove from area
      // guards do not despawn
      if (!isGuard && _turnsInvisible > DESPAWN_TIMER)
        game.area.removeAI(this);
    }


// logic: slime
  function effectSlime()
    {
      var free = effects.decrease(EFFECT_SLIME, strength);
      if (free)
        log('manages to get free of the mucus.');
      else log('desperately tries to get free of the mucus.');

      // set alerted state
      if (state == AI_STATE_IDLE)
        setState(AI_STATE_ALERT, REASON_DAMAGE);

      emitRandomSound('' + REASON_DAMAGE, 30); // emit random sound
    }


// call AI logic
  public function turn()
    {
      stateTime++; // time spent in this state
      if (entity != null)
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

      // idle - roam around or guard, etc
      else if (state == AI_STATE_IDLE)
        stateIdle();

      // AI alerted - try to run away or attack
      else if (state == AI_STATE_ALERT)
        stateAlert();

      // controlled by parasite
      else if (state == AI_STATE_HOST)
        stateHost();

      // preserved - do nothing
      else if (state == AI_STATE_PRESERVED)
        1;

      // move to target x,y
      else if (state == AI_STATE_MOVE_TARGET)
        stateMoveTarget();

      // post-detach
      else if (state == AI_STATE_POST_DETACH && stateTime >= 2)
        setState(AI_STATE_ALERT, REASON_DETACH);

      updateEntity(); // clamp and change entity icons
      checkDespawn(); // check for this AI to despawn

      // emit random sound if it exists
      // assimilated hosts do not emit random sounds
      if (state != AI_STATE_HOST || !hasTrait(TRAIT_ASSIMILATED))
        emitRandomSound('' + state, 20);
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

      emitSound(sound);
    }


// emit specific sound (both visual and audio if it exists)
// also handle sound propagation here
  public function emitSound(sound: AISound)
    {
      // check for min alertness
      if (state == AI_STATE_IDLE &&
          sound.params != null &&
          sound.params.minAlertness != null &&
          alertness < sound.params.minAlertness)
        return;

      // check if AI is visible
      if (!game.area.inVisibleRect(x, y))
        return;

      if (sound.text != '' && sound.text != null)
        entity.setText(sound.text, 2);
      if (sound.file != null)
        {
          var file = sound.file;
          if (isHuman && !isMale && file.indexOf('male') == 0)
            file = 'fe' + file;
          var opts: _SoundOptions = {
            x: x,
            y: y,
            canDelay: true,
            // attack sounds always play
            always: (file.indexOf('attack') == 0),
          };
          game.scene.sounds.play(file, opts);
        }
      if (sound.radius <= 0 || sound.alertness <= 0)
        return;

      // get a list of AIs in that radius without los checks and give alertness bonus
      var list = game.area.getAIinRadius(x, y, sound.radius, false);
      for (ai in list)
        if (ai.state == AI_STATE_IDLE ||
            ai.state == AI_STATE_MOVE_TARGET)
          {
//            trace('' + ai.id + ' ' + ai,type + ' alert ' + ai.alertness + ' +' + sound.alertness);
            ai.alertness += sound.alertness;
          }
    }

// ============================ EVENTS ===============================


// event: AI receives damage
  public function onDamage(damage: Int)
    {
      organs.onDamage(damage); // propagate event to organs
      health -= damage;
      if (health == 0) // AI death
        {
          die();

          return;
        }

      // set alerted state
      if (state == AI_STATE_IDLE)
        setState(AI_STATE_ALERT, REASON_DAMAGE);

      emitRandomSound('' + REASON_DAMAGE, 30); // emit random sound
    }


// AI death in the sewers
  public function dieRegion()
    {
      // dying sound
      var array = sounds['' + AI_STATE_DEAD];
      if (array == null)
        return;
      var idx = Std.random(array.length);
      var sound = array[idx];
      var file = sound.file;
      if (isHuman && !isMale && file.indexOf('male') == 0)
        file = 'fe' + file;
      game.scene.sounds.play(file);

      // event stuff
      if (npc != null)
        {
          npc.isDead = true;
          npc.statusKnown = true;
        }
    }


// AI death
  public function die()
    {
      // AI already dead from another call
      if (state == AI_STATE_DEAD)
        return;

      // dying sound
      emitRandomSound('' + AI_STATE_DEAD);

      game.debug('AI.die[' + id + ']');
      if (game.player.state != PLR_STATE_HOST ||
          game.player.host != this)
        log('dies.');
      onDeath(); // event hook
      setState(AI_STATE_DEAD);
      game.area.removeAI(this);
      var o = new BodyObject(game, game.area.id, x, y, type);

      // decay acceleration
      var organ = organs.getActive(IMP_DECAY_ACCEL);
      if (organ != null)
        {
          o.setDecay(organ.params.turns);
          o.isDecayAccel = true;
        }

      o.organPoints = organs.getPoints();
      o.inventory = inventory; // copy inventory
      game.scene.updateCamera();

      // event stuff
      if (npc != null)
        {
          npc.isDead = true;
          npc.statusKnown = true;
        }
    }


// event: parasite attached to this host
  public inline function onAttach()
    {
      // set AI state
      parasiteAttached = true;
      wasAttached = true; // mark as touched by parasite
      setState(AI_STATE_ALERT, REASON_ATTACH);
      updateMask(Const.FRAME_MASK_ATTACHED);
    }

  public function updateMask(x: Int)
    {
      entity.setMask(game.scene.entityAtlas[x][Const.ROW_PARASITE]);
    }

// event: parasite invaded this host
  public inline function onInvade()
    {
      setState(AI_STATE_HOST);
      parasiteAttached = false;
      wasInvaded = true; // mark as invaded
      updateMask(Const.FRAME_MASK_CONTROL);

      // add effect marker so that AI can't tear parasite away
      onEffect({
        type: EFFECT_CANNOT_TEAR_AWAY,
        points: 5,
        isTimer: true
      });
    }


// event: parasite detach from this host
  public inline function onDetach(src: String)
    {
      if (src == 'default')
        setState(AI_STATE_POST_DETACH, null, 'feels groggy and confused.');
      else if (src == 'preservator')
        setState(AI_STATE_PRESERVED, null, 'stands still motionlessly.');
      entity.setMask(null);
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


// event dynamic: on despawning live AI
  public dynamic function onRemove()
    {}


// event dynamic: on AI death
  public dynamic function onDeath()
    {}


// event dynamic: on being noticed by player
  public dynamic function onNotice()
    {}


// =================================================================================


// log
  public inline function log(s: String, ?col: _TextColor = null)
    {
      game.log(getNameCapped() + ' ' + s, col);
    }

  public function toString()
    {
      return getName() + ' (' + x + ',' + y + '): ' + type + ', ' + job;
    }


// ========================== SETTERS ====================================

  function get_event(): scenario.Event
    {
      if (eventID == null)
        return null;
      else return game.timeline.getEvent(eventID);
    }

  function get_npc(): scenario.NPC
    {
      if (npcID < 0 || !isNPC)
        return null;
      return event.getNPC(npcID);
    }

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
  function get_maxOrgans()
    {
      // CON human: 4-8, dog: 2-6
      // BASE human: 2-4, dog: 1-3
      // ASSIM human: 4-6, dog: 3-5
      var x = Std.int(constitution / 2);
      return (x > 0 ? x : 1) + (hasTrait(TRAIT_ASSIMILATED) ? 2 : 0);
    }
  function get_maxItems()
    {
      // STR human: 4-8
      // BASE human: 6-10
      // ASSIM human: 8-12
      return strength + 2 + (hasTrait(TRAIT_ASSIMILATED) ? 2 : 0);
    }

// =================================================================================
  // AI view and hear distance
  // recalculated in GameScene.begin() at game start
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
  REASON_BODY_SILENT;
  REASON_BACKUP;
  REASON_ATTACH;
  REASON_DETACH;
  REASON_HOST;
  REASON_PARASITE;
  REASON_DAMAGE;
  REASON_WITNESS;
}

@:structInit
class _AIName extends _SaveObject
{
  public var real: String; // real name
  public var realCapped: String; // capitalized real name
  public var unknown: String; // class name
  public var unknownCapped: String; // class name capitalized

  public function new(real: String, realCapped: String, unknown: String, unknownCapped: String)
    {
      this.real = real;
      this.realCapped = realCapped;
      this.unknown = unknown;
      this.unknownCapped = unknownCapped;
    }
}

@:structInit
class _AITimers extends _SaveObject
{
  public var alert: Int; // alerted, count down until AI calms down
    // alerted and player not visible, count down
//    alertPlayerNotVisible: Int,

  public function new(alert: Int)
    {
      this.alert = alert;
    }
}
