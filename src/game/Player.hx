// player state

package game;

import ai.AI;
import game.Skills;
import const.*;

class Player extends _SaveObject
{
  static var _ignoredFields = [];
  var game: Game; // game state link

  public var difficulty: _Difficulty; // survival difficulty
  public var saveDifficulty: _Difficulty; // save difficulty
  public var evolutionManager: EvolutionManager; // main evolution control
  public var chat: Chat; // chat manager

  // state-independent
  public var energy(default, set): Int; // energy left
  public var maxEnergy: Int; // max energy
  public var health(default, set): Int; // current health
  public var maxHealth: Int; // maximum health
  var knownItems: List<String>; // list of known item types

  public var vars: PlayerVars; // player variables
  public var skills: Skills; // skills
  public var state: _PlayerState; // player state - parasite, attach, host

  // state "host" - store host link here because host exists in all modes
  public var host: AI; // invaded host
  public var hostID: Int;
  public var hostControl(default, set): Int; // amount of turns until you lose control of the host


  public function new(g: Game)
    {
      game = g;
      evolutionManager = new EvolutionManager(this, game);
      difficulty = UNSET;
      saveDifficulty = UNSET;
      chat = new Chat(this, game);

      vars = {
        inventoryEnabled: false,
        objectsEnabled: false,
        skillsEnabled: false,
        timelineEnabled: false,
        organsEnabled: false,
        npcEnabled: false,
        searchEnabled: false,
        habitatsLeft: 1000,
        savesLeft: -1,
        mapAbsorbed: false,

        evolutionEnergyPerTurn: 5,
        evolutionEnergyPerTurnMicrohabitat: 4,
        organGrowthEnergyPerTurn: 5,
        organGrowthPointsPerTurn: 10,

        areaEnergyPerTurn: 5,
        regionEnergyPerTurn: 15,
        startHealth: 10,
        startEnergy: 50,
        maxEnergy: 100,
        listenRadius: 10,
        losEnabled: true,
        invisibilityEnabled: false,
        godmodeEnabled: false,
        isSpoonGame: game.config.isSpoonMode(),
        debugSoundEnabled: false,
      };

      state = PLR_STATE_PARASITE;
      maxEnergy = vars.maxEnergy; // first set max for correct clamping
      energy = vars.startEnergy;
      maxHealth = vars.startHealth;
      health = vars.startHealth;
      hostControl = 0;
      knownItems = new List<String>();
      host = null;
      hostID = -1;

      skills = new Skills(game, true);
    }

// called post-loading game
  public function loadPost()
    {
      // NOTE: in area mode we rewrite the serialized ai copy replacing it with link
      // in region mode we use serialized ai
      if (game.location == LOCATION_AREA)
        {
          if (host != null)
            {
              if (host.entity != null)
                host.entity = null;
              host = null;
            }
          if (state == PLR_STATE_HOST && hostID >= 0)
            {
              host = game.area.getAIByID(hostID);
              host.updateMask(Const.FRAME_MASK_CONTROL);
            }
        }
      // fix player icon from previous game
      else if (game.location == LOCATION_REGION &&
          state == PLR_STATE_PARASITE)
        {
          // set entity image
          game.playerRegion.resetEntity();
        }
      skills.loadPost();
      game.playerRegion.loadPost();
    }

// end of turn for player
  public function turn()
    {
      var time = 1;

      // different time speed in region mode
      if (game.location == LOCATION_REGION)
        time = 5;

      // parasite state: energy and health
      if (state == PLR_STATE_PARASITE)
        {
          var delta = __Math.parasiteEnergyPerTurn(time);
          // DEBUG: godmode
          if (!vars.godmodeEnabled)
            energy += delta;

          if (state == PLR_STATE_PARASITE && energy <= 0)
            {
              death('noHost');
              return;
            }
        }

      // all states: restore health in habitat
      if (game.location == LOCATION_AREA &&
          game.area.isHabitat)
        health += game.area.habitat.parasiteHealthRestored * time;

      // host state: host energy
      // host can die, so we still need to check for state later
      if (state == PLR_STATE_HOST)
        {
          var delta = __Math.hostEnergyPerTurn(time);
          var old = host.energy;
          // DEBUG: godmode
          if (!vars.godmodeEnabled)
            host.energy += delta;

          if (host.energy <= 0)
            onHostDeath('Your host has expired. You have to find a new one.');

          // tutorial if host is alive
          else if (host.energy < 0.3 * host.maxEnergy &&
                   old >= 0.3 * host.maxEnergy)
            game.goals.complete(GOAL_TUTORIAL_ENERGY);
        }

      // more host state checks
      // we check for the 2nd time, because host could die in previous block
      if (state == PLR_STATE_HOST)
        {
          // parasite energy restoration
          var delta = __Math.parasiteEnergyPerTurn(time);
          energy += delta;
          // increase affinity
          host.gainAffinity(time * 2);

          host.organs.turn(time); // host organ growth

          // knowledge about human society raises automatically
          // if host memory is available
          if (host.type == 'human' &&
              evolutionManager.getLevel(IMP_BRAIN_PROBE) > 0)
            skills.increase(KNOW_SOCIETY, 0.1 * host.intellect * time);

          // evolution can kill host (change state)
          evolutionManager.turn(time);
        }

      // location-specific turn
      if (game.location == LOCATION_AREA)
        game.playerArea.turn();

      else if (game.location == LOCATION_REGION)
        game.playerRegion.turn(time);
    }

// parasite death: either rebirth or game over
  public function death(text: String)
    {
      // last life
      var ovum = evolutionManager.ovum;
      if (ovum.level == 0)
        {
          game.finish('lose', text, 'event/death');
          return;
        }

      // rebirth process
      // detach
      if (state == PLR_STATE_ATTACHED)
        game.playerArea.detachAction();
      game.log('You fade into the darkness...');
      // restore health
      health = maxHealth;
      energy = maxEnergy; // bug fix?
      // NOTE: energy is restored in rebirthPost
      game.turns += 9;
      // remove old improvements
      var cntLocked = 0;
      var degraded = [];
      var removed = [];
      for (imp in evolutionManager)
        {
          // reset all evolution points in any case
          if (imp.level > 0)
            imp.ep = EvolutionConst.epCostImprovement[imp.level - 1];
          // strong chance of losing a level
          if (imp.level > 1 && Std.random(100) < 50)
            {
              imp.level--;
              imp.ep = EvolutionConst.epCostImprovement[imp.level - 1];
              degraded.push(imp.info.name);
            }
          // locked in ovum and under its level
          if (imp.isLocked && cntLocked < ovum.level)
            {
              cntLocked++;
              continue;
            }
          // do not touch non-basic imps
          if (imp.info.type != TYPE_BASIC)
            continue;
          evolutionManager.removeImprov(imp.id, true);
          removed.push(imp.info.name);
        }
      if (degraded.length > 0)
        game.log(Const.small('Improvements degraded: ' + degraded.join(', ') + '.'), COLOR_EVOLUTION);
      if (removed.length > 0)
        game.log(Const.small('Improvements lost: ' + removed.join(', ') + '.'), COLOR_EVOLUTION);
      // add new improvements
      evolutionManager.giveStartingImprovements();
      // ovum loses a level (after improvements reset)
      ovum.level--;
      if (ovum.level == 0)
        ovum.xp = 0;
      else ovum.xp = EvolutionConst.ovumXP[ovum.level - 1];

      // leave area and teleport
      if (game.location == LOCATION_AREA)
        game.setLocation(LOCATION_REGION);
      var ovumObj = game.region.getObjectsWithType('ovum')[0];
      game.playerRegion.moveTo(ovumObj.x, ovumObj.y, false);
      // message
      var msgs = [
        'I am reborn.',
        'I live again.',
        'Birth, death and rebirth. The purifying rhythm of the universe.',
        'I am alive. Alive.',
      ];
      game.message(msgs[Std.random(msgs.length)]);
      game.scene.sounds.play('parasite-rebirth');
      game.isFinished = true; // temp kludge for rebirth
      game.isRebirth = true;
    }

// called after turn is over
  public function rebirthPost()
    {
      // clear flags
      game.isRebirth = false;
      game.isFinished = false;
      // restore energy
      energy = maxEnergy;
    }

// returns true if player/host has enough energy for this action
// NOTE: needs to be the same checks as in actionEnergy()
  public function actionCheckEnergy(action: _PlayerAction): Bool
    {
      var e = 0;
      if (action.energy != null)
        e = action.energy;
      else if (action.energyFunc != null)
        e = action.energyFunc(game.player);
      if (e < 0)
        return false;

      // chatting spends parasite energy
      if (action.type == ACTION_CHAT)
        {
          if (energy >= e)
            return true;
          else return false;
        }
      else if (state == PLR_STATE_HOST &&
          host.energy >= e)
        return true;
      else if (energy >= e)
        return true;
      return false;
    }

// spend energy specified in the action according to player state rules
// NOTE: needs to be the same checks as in actionCheckEnergy()
  public function actionEnergy(action: _PlayerAction)
    {
      // spend energy
      if (action.energy != null)
        {
          // chatting spends parasite energy
          if (action.type == ACTION_CHAT)
            energy -= action.energy;
          else if (state == PLR_STATE_HOST)
            host.energy -= action.energy;
          else energy -= action.energy;
        }
      else if (action.energyFunc != null)
        {
          // chatting spends parasite energy
          if (action.type == ACTION_CHAT)
            energy -= action.energyFunc(this);
          else if (state == PLR_STATE_HOST)
            host.energy -= action.energyFunc(this);
          else energy -= action.energyFunc(this);
        }

      // NOTE: death from no energy is handled in actionPost()
    }

// convenience method for host death
  public inline function onHostDeath(msg: String)
    {
      // reduce max energy from affinity
      if (host.affinity >= 100)
        {
          msg += ' You feel great pain due to the affinity.';
          maxEnergy -= 5;
          energy = energy; // clamp current value
        }
      if (game.location == LOCATION_AREA)
        {
          // message on first death
          if (host.isHuman)
            game.goals.complete(GOAL_TUTORIAL_BODY);

          game.playerArea.onHostDeath();
        }

      else if (game.location == LOCATION_REGION)
        {
          // message on first death
          if (host.isHuman)
            {
              game.goals.complete(GOAL_TUTORIAL_BODY_SEWERS);
              game.goals.complete(GOAL_TUTORIAL_BODY, SILENT_ALL);
            }
          game.playerRegion.onHostDeath();
        }

      // stop moving
      game.scene.clearPath();
      log(msg);
      game.profile.addPediaArticle('hostExpiry');
    }


// add item to known list
  public inline function addKnownItem(id: String)
    {
      return knownItems.add(id);
    }


// does player know about this item?
  public inline function knowsItem(id: String): Bool
    {
      return (ItemsConst.getInfo(id).isKnown ||
        Lambda.has(knownItems, id));
    }

// helper function to teleport to any area
// additionally move to spot
  public function teleport(area: AreaGame, ?x: Int = -1, ?y: Int = -1)
    {
      // leave current area
      if (game.location == LOCATION_AREA)
        game.setLocation(LOCATION_REGION);

      // move to new location
      game.playerRegion.moveTo(area.x, area.y, false);

      // enter area
      game.setLocation(LOCATION_AREA);

      if (x != -1 && y != -1)
        game.playerArea.moveTo(x, y);

      game.updateHUD();
      game.scene.updateCamera();
      game.area.updateVisibility();
    }

// learn skill at that amount (common part for brain probe and chat)
  public function learnSkill(targetSkill: Skill, amount: Int)
    {
      var skill = skills.get(targetSkill.id);
      if (skill == null)
        {
          log('You have learned the basics of ' + targetSkill.info.name + ' skill.');
          skills.addID(targetSkill.id, amount);
        }
      else if (!targetSkill.info.isBool)
        {
          log('You have increased your proficiency in ' + targetSkill.info.name +
            ' skill.');
          var val = Const.clampFloat(skill.level + amount, 0, targetSkill.level);
          skills.increase(targetSkill.id, val - skill.level);
        }
    }

// returns true if player has consent of the host
  public inline function hasConsent(): Bool
    {
      return (state == PLR_STATE_HOST &&
        host != null && 
        host.chat.consent >= 100);
    }

// returns true if the host is agreeable
  public inline function hostAgreeable(): Bool
    {
      return (state == PLR_STATE_HOST &&
        host.isAgreeable());
    }

// =================================================================================


// log
  public inline function log(s: String, ?col: _TextColor)
    {
      game.log(s, col);
    }


// =================================  SETTERS  ====================================
  function set_energy(v: Int)
    { return energy = Const.clamp(v, 0, maxEnergy); }
  function set_health(v: Int)
    { return health = Const.clamp(v, 0, maxHealth); }
  function set_hostControl(v: Int)
    { return hostControl = Const.clamp(v, 0, 100); }


// =================================================================================


  // base amount of turns the host has to live
//  public static var HOST_EXPIRY_TURNS = 10;

  // base control on invade
  public static var HOST_CONTROL_BASE = 10;
  public static var HOST_CONTROL_ASSIMILATED = 50;
}

