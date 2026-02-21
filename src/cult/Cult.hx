// cult structure
package cult;

import game.AreaEvent;
import game.AreaGame;
import game.Game;
import ai.AI;
import ai.AIData;
import cult.effects.*;
import Type;

class Cult extends _SaveObject
{
  public var game: Game;
  public var id: Int;
  public static var _maxID: Int = 0; // current max ID
  public var state: _CultState;
  // NOTE: cult members exist both in world and in this list
  // we updateData() here on despawn
  // and we use updateData() on spawn, too
  public var members: Array<AIData>;
  public var leader(get, null): AIData;
  public var isPlayer: Bool;
  public var name: String;
  public var power: _CultPower;
  public var resources: _CultPower;
  public var ordeals: Ordeals;
  public var effects: Effects;
  public var trainingMemberIDs: Array<Int>; // members locked for training until next cult turn
  var turnCounter: Int;

  public function new(g: Game)
    {
      game = g;
      id = (_maxID++);
      state = CULT_STATE_INACTIVE;
      members = [];
      isPlayer = false;
      name = 'Cultus Carnis';
      init();
      initPost(false);
    }

// init object before loading/post creation
// NOTE: new object fields should init here!
  public function init()
    {
      ordeals = new Ordeals(game);
      effects = new Effects(game, this);
      power = {
        combat: 0,
        media: 0,
        lawfare: 0,
        corporate: 0,
        political: 0,
        occult: 0,
        money: 0
      };
      resources = {
        combat: 0,
        media: 0,
        lawfare: 0,
        corporate: 0,
        political: 0,
        occult: 0,
        money: 0
      };
      trainingMemberIDs = [];
    }

// called after load or creation
  public function initPost(onLoad: Bool)
    {
      if (effects == null)
        effects = new Effects(game, this);
      else
        {
          effects.game = game;
          effects.cult = this;
        }
      if (trainingMemberIDs == null)
        trainingMemberIDs = [];
    }

// post load
  public function loadPost()
    {
      for (ai in members)
        if (ai.id > AIData._maxID)
          AIData._maxID = ai.id;

      // set Mission._maxID to maximum mission id + 1
      var maxMissionID = 0;
      for (ordeal in ordeals.list)
        for (mission in ordeal.missions)
          if (mission.id > maxMissionID)
            maxMissionID = mission.id;
      Mission._maxID = maxMissionID + 1;
    }

// create cult (add leader)
  public function addLeader(ai: AI)
    {
      state = CULT_STATE_ACTIVE;
      ai.isNameKnown = true;
      ai.isJobKnown = true;
      ai.setCult(this);
      members.push(ai.cloneData());
      log('gains a leader: ' + ai.theName());
      if (isPlayer)
        game.ui.event({
          type: UIEVENT_HIGHLIGHT,
          state: UISTATE_CULT,
        });
      recalc();
    }

// add new member
  public function addMember(ai: AI)
    {
      var ret = addAIData(ai.cloneData());
      if (!ret)
        return;
      ai.isNameKnown = true;
      ai.isJobKnown = true;
      ai.setCult(this);
    }

// add member from AIData
// NOTE: this is called from recruit follower/chat
  public function addAIData(aidata: AIData): Bool
    {
      // check for max cultists
      if (members.length >= maxSize())
        {
          game.actionFailed('Maximum number of members reached.');
          return false;
        }

      // check for max jobs
      var jobInfo = game.jobs.getJobInfo(aidata.job);
      if (jobInfo == null)
        {
          game.actionFailed('Unknown job.');
          return false;
        }
      var level = jobInfo.level;
      var levelLimit = getLevelLimit(level);
      if (levelLimit >= 0 &&
          countMembers(level) >= levelLimit)
        {
          game.actionFailed('Maximum number of level ' + level + ' members reached.');
          return false;
        }

      aidata.isNameKnown = true;
      aidata.isCultist = true;
      aidata.cultID = id;
      members.push(aidata);
      log('gains a new member: ' + aidata.TheName());
      recalc();
      return true;
    }

// when ai is removed from area, we need to update members
  public function onRemoveAI(ai: AI)
    {
      // find member record
      var aidata = null;
      for (m in members)
        if (m.id == ai.id)
          {
            aidata = m;
            break;
          }

      // ai is dead
      if (ai.state == AI_STATE_DEAD)
        {
          onDeath(aidata);
        }

      else aidata.updateData(ai, 'on despawn');
    }

// update member data from ai
  public function updateData(ai: AI)
    {
      // find member record
      var aidata = null;
      for (m in members)
        if (m.id == ai.id)
          {
            aidata = m;
            break;
          }
      if (aidata == null)
        return;
      aidata.updateData(ai, 'on update');
    }

// handle member death
  public function onDeath(aidata: AIData)
    {
      ordeals.onDeath(aidata);
      // leader is dead
      if (members[0].id == aidata.id)
        destroy();
      members.remove(aidata);
      recalc();
    }

// leader is dead - destroy cult
  function destroy()
    {
      members = [];
      effects.list = [];
      ordeals.list = [];
      state = CULT_STATE_DEAD;
      if (!isPlayer)
        {
          game.cults.remove(this);
          log(' is destroyed, forgotten by time');
        }
      else log(' is temporarily out of action');

      // clear live ai in the current area
      if (game.area != null)
        clearCultistsInArea(game.area, game.area.isHabitat);
      // clear cultists from player habitats
      clearCultistsInHabitats();
    }

// run cult action from ui
// returns true if action should close window
  public function action(action: _PlayerAction): Bool
    {
      var ret = false;
      switch (action.id)
        {
          case 'callHelp':
            ret = callHelpAction(action);
          case 'callMember':
            ret = callMemberAction(action);
        }
      if (!ret)
        return true;
      game.playerArea.actionPost(); // post-action call
      return true;
    }

// returns true if player can call for help
  public function canCallHelp(): Bool
    {
      if (state != CULT_STATE_ACTIVE)
        return false;
      if (game.location != LOCATION_AREA)
        return false;
      // check if another call action is in progress
      if (game.managerArea != null)
        {
          var events = game.managerArea.getList();
          for (e in events)
            if (e.type == AREAEVENT_ARRIVE_CULTIST)
              return false;
        }
      return true;
    }

// get free members with specified level or higher
  public function getFreeMembers(level: Int, ?onlyGivenLevel: Bool = false): Array<Int>
    {
      // get map of locked cultist IDs from ordeals
      var lockedIDs = new Map<Int, Bool>();
      for (ordeal in ordeals.list)
        {
          var locked = ordeal.getLockedCultists();
          for (id in locked)
            lockedIDs.set(id, true);
        }

      // get map of blocked cultist IDs from effects
      var blockedIDs = new Map<Int, Bool>();
      if (effects.has(CULT_EFFECT_BLOCK_CULTIST))
        {
          var blockEffects = effects.get(CULT_EFFECT_BLOCK_CULTIST);
          for (effect in blockEffects)
            {
              var blockEffect = cast(effect, BlockCultist);
              blockedIDs.set(blockEffect.targetID, true);
            }
        }

      var free = [];
      for (ai in members)
        {
          // check if member is locked in an ordeal
          if (lockedIDs.exists(ai.id))
            continue;

          // check if member is blocked by effect
          if (blockedIDs.exists(ai.id))
            continue;

          // check if member is locked in training
          if (isTraining(ai.id))
            continue;

          // check if cultist is already in this area
          if (game.location == LOCATION_AREA &&
              game.area != null)
            {
              var tmp = game.area.getAIByID(ai.id);
              if (tmp != null)
                continue;
            }

          // check if cultist is player host (region mostly)
          if (game.player.state == PLR_STATE_HOST &&
              game.player.host.id == ai.id)
            continue;

          // check member level
          var jobInfo = game.jobs.getJobInfo(ai.job);
          if (jobInfo != null)
            {
              if ((onlyGivenLevel && jobInfo.level == level) ||
                  (!onlyGivenLevel && jobInfo.level >= level))
                free.push(ai.id);
            }
        }
      return free;
    }

// get member by ID
  public function getMemberByID(memberID: Int): AIData
    {
      for (m in members)
        {
          if (m.id == memberID)
            return m;
        }
      return null;
    }

// checks whether member is currently locked in training
  public function isTraining(memberID: Int): Bool
    {
      return (trainingMemberIDs.indexOf(memberID) >= 0);
    }

// locks a free member for training
  public function setTraining(memberID: Int): Bool
    {
      if (getMemberStatus(memberID) != '')
        return false;
      if (isTraining(memberID))
        return false;
      trainingMemberIDs.push(memberID);
      return true;
    }

// clears all training member locks
  public function clearTraining()
    {
      trainingMemberIDs = [];
    }

// get member status string
// NOTE: returns empty string if member is free
  public function getMemberStatus(memberID: Int): String
    {
      var member = getMemberByID(memberID);
      if (member == null)
        return '';

      // check if member is locked in an ordeal
      var lockedIDs = new Map<Int, Bool>();
      for (ordeal in ordeals.list)
        {
          var locked = ordeal.getLockedCultists();
          for (id in locked)
            lockedIDs.set(id, true);
        }

      if (lockedIDs.exists(memberID))
        return '[in ordeal]';

      // check if member is blocked by effect
      if (effects.has(CULT_EFFECT_BLOCK_CULTIST))
        {
          var blockEffects = effects.get(CULT_EFFECT_BLOCK_CULTIST);
          for (effect in blockEffects)
            {
              var blockEffect = cast(effect, BlockCultist);
              if (blockEffect.targetID == memberID)
                return '[in recessu]';
            }
        }

      if (isTraining(memberID))
        return '[training]';

      // check if cultist is on area
      if (game.location == LOCATION_AREA &&
          game.area != null)
        {
          var tmp = game.area.getAIByID(memberID);
          if (tmp != null)
            return '[on location]';
        }

      // check if cultist is player host (region mostly)
      if (game.player.state == PLR_STATE_HOST &&
          game.player.host.id == memberID)
        return '[host]';

      return '';
    }

// call for help
  function callHelpAction(action: _PlayerAction): Bool
    {
      // find what cultists are available
      var free = getFreeMembers(1);
      if (free.length == 0)
        {
          game.actionFailed('There are no more faithful available.');
          return false;
        }
      game.log('You send out a call to the faithful.');

      // roll a number
      var num = Const.roll(1, 4);
      if (num > free.length)
        num = free.length;
      while (num > 0)
        {
          // generate an event
          num--;
          game.managerArea.add(AREAEVENT_ARRIVE_CULTIST,
            game.playerArea.x, game.playerArea.y, 5);
        }
      return true;
    }

// call specific member
  function callMemberAction(action: _PlayerAction): Bool
    {
      var m = getMemberByID(action.obj.memberID);
      game.log('You summon ' + m.TheName() + ' to your side.');

      // generate event with memberID in details
      // create a simple params object
      var paramsObj = new ArriveCultistParams();
      paramsObj.memberID = action.obj.memberID;
      game.managerArea.add(AREAEVENT_ARRIVE_CULTIST,
        game.playerArea.x, game.playerArea.y, 5, paramsObj);

      return true;
    }

// area manager: cultist arrives
  public function onArriveCultist(e: AreaEvent)
    {
      if (game.cults[0].state != CULT_STATE_ACTIVE)
        return;
      // check for difficult help effect and roll failure chance
      if (effects.has(CULT_EFFECT_DIFFICULT_HELP))
        {
          var effs = effects.get(CULT_EFFECT_DIFFICULT_HELP);
          if (effs.length > 0)
            {
              var e = cast(effs[0], DifficultHelp);
              var roll = Std.random(100);
              if (roll <= e.percent)
                {
                  game.logsg('The call has failed to reach some of the faithful.');
                  return;
                }
            }
        }

      // check if memberID is specified in params
      var memberID: Int = -1;
      if (e.params != null)
        {
          var params = cast(e.params, ArriveCultistParams);
          memberID = params.memberID;
        }

      // if no memberID specified, pick a random free cultist
      if (memberID == -1)
        {
          // find what cultists are still available
          var freeIDs = getFreeMembers(1);
          if (freeIDs.length == 0)
            return;

          // pick a cultist
          var idx = Std.random(freeIDs.length);
          memberID = freeIDs[idx];
        }
      
      var aidata = getMemberByID(memberID);
      if (aidata == null)
        return;
      
      // check if specified member is free
      if (getMemberStatus(memberID) != '')
        return;
      game.debug(aidata.TheName() + ' has arrived.');
//          log('calls for help: ' + ai.theName());
      game.scene.sounds.play('ai-arrive-security', {
        x: e.x,
        y: e.y,
        canDelay: true,
        always: false,
      });

      // find location
      var loc = game.area.findArriveLocation({
        near: { x: e.x, y: e.y },
        radius: 10,
        fallbackRadius: 5
      });
      if (loc == null)
        {
          Const.todo('Could not find free spot for spawn (cultist help)!');
          return;
        }

      // spawn ai and update it from cultist data
      var ai = game.area.spawnAI(aidata.type, loc.x, loc.y, false);
      ai.updateData(aidata, 'on spawn');
      game.area.addAI(ai);

      // arrives already alerted
      ai.timers.alert = 10;
      ai.state = AI_STATE_ALERT;

      // set roam target
      ai.roamTargetX = e.x;
      ai.roamTargetY = e.y;
    }

// cult turn
  public function turn(time: Int)
    {
      if (state != CULT_STATE_ACTIVE)
        return;
      // pause passage of time when in mission area
      if (game.player.inMissionArea())
        return;

      if (members.length == 0)
        return;
      // cult needs 10 player turns to tick
      turnCounter += time;
      if (turnCounter < 10)
        return;
      turnCounter = 0;

      // clear previous training locks at cult turn start
      clearTraining();

      // just in case
      recalc();
      
      // store old resource values for delta calculation
      var delta: _CultPower = {
        combat: resources.combat,
        media: resources.media,
        lawfare: resources.lawfare,
        corporate: resources.corporate,
        political: resources.political,
        occult: resources.occult,
        money: resources.money
      };
      
      // increase resources by 1 for each 3 power of the same type
      resources.combat += Std.int(power.combat / 3);
      resources.media += Std.int(power.media / 3);
      resources.lawfare += Std.int(power.lawfare / 3);
      resources.corporate += Std.int(power.corporate / 3);
      resources.political += Std.int(power.political / 3);
      
      // money: collect 50% to resources
      resources.money += Std.int(power.money * 0.5);
      
      // process ordeals turn
      ordeals.turn();
      // process active cult effects
      effects.turn();
      // process member regeneration
      turnMembers();
      
      // modify delta in place
      delta.combat = resources.combat - delta.combat;
      delta.media = resources.media - delta.media;
      delta.lawfare = resources.lawfare - delta.lawfare;
      delta.corporate = resources.corporate - delta.corporate;
      delta.political = resources.political - delta.political;
      delta.money = resources.money - delta.money;

/*
      game.logsg(name +
        ' turn: COM ' + resources.combat + (delta.combat > 0 ? ' (+' + delta.combat + ')' : '') +
        ', MED ' + resources.media + (delta.media > 0 ? ' (+' + delta.media + ')' : '') +
        ', LAW ' + resources.lawfare + (delta.lawfare > 0 ? ' (+' + delta.lawfare + ')' : '') +
        ', COR ' + resources.corporate + (delta.corporate > 0 ? ' (+' + delta.corporate + ')' : '') +
        ', POL ' + resources.political + (delta.political > 0 ? ' (+' + delta.political + ')' : '') +
        ', MONEY ' + resources.money + (delta.money > 0 ? ' (+' + delta.money + ')' : ''));
      game.scene.sounds.play('click-action');
*/
    }

// process member regeneration for free members
  function turnMembers()
    {
      for (m in members)
        {
          // only process free members
          if (getMemberStatus(m.id) != '')
            continue;
          
          // add +10 energy up to maximum
          m.energy += 10;
          if (m.energy > m.maxEnergy)
            m.energy = m.maxEnergy;
          
          // 10% chance to regen 1 hp
          if (Std.random(100) < 10)
            {
              m.health += 1;
              if (m.health > m.maxHealth)
                m.health = m.maxHealth;
            }
        }
    }

// recalculate cult power and resources from members
  public function recalc()
    {
      // reset all values
      power.combat = 0;
      power.media = 0;
      power.lawfare = 0;
      power.corporate = 0;
      power.political = 0;
      power.money = 0;

      // calculate power/income from all members
      for (member in members)
        {
          var status = getMemberStatus(member.id);
          if (status != '')
            continue; // only free members
          power.money += member.income;

          // get job info by name
          var jobInfo = game.jobs.getJobInfo(member.job);
          if (jobInfo == null)
            continue;

          // skip civilian jobs
          if (jobInfo.group == GROUP_CIVILIAN)
            continue;

          // calculate points based on level
          var ptsmap = [
            1 => 1,
            2 => 3,
            3 => 10
          ];
          var points = ptsmap[jobInfo.level];
          if (points == null)
            points = 0;

          // add points to power according to group
          switch (jobInfo.group)
            {
              case GROUP_COMBAT:
                power.combat += points;
              case GROUP_MEDIA:
                power.media += points;
              case GROUP_LAWFARE:
                power.lawfare += points;
              case GROUP_CORPORATE:
                power.corporate += points;
              case GROUP_POLITICAL:
                power.political += points;
              default:
            }
        }

      // run effect hooks that modify power/income
      for (effect in effects)
        {
          if (effect.type == CULT_EFFECT_INCREASE_POWER ||
              effect.type == CULT_EFFECT_DECREASE_POWER ||
              effect.type == CULT_EFFECT_INCREASE_INCOME ||
              effect.type == CULT_EFFECT_DECREASE_INCOME)
            effect.run(this);
        }
    }

// styled cult name
  public function Name()
    {
      return '<span class=cult>' + name + '</span>';
    }

// cult log
  public function log(text: String)
    {
      if (isPlayer)
        game.log(Name() + ' ' + text + '.');
    }

// cult log (no dot)
  public function logNoDot(text: String)
    {
      if (isPlayer)
        game.log(Name() + ' ' + text);
    }

// cult log (small gray helper)
  public function logsg(text: String)
    {
      if (isPlayer)
        game.log(Const.smallgray(Name() + ' ' + text));
    }

// max cult size
  public function maxSize(): Int
    {
      return 10;
    }

// counts current cult members at specified job level
  public function countMembers(level: Int): Int
    {
      var count = 0;
      for (member in members)
        {
          var memberJob = game.jobs.getJobInfo(member.job);
          if (memberJob != null && memberJob.level == level)
            count++;
        }
      return count;
    }

// returns maximum allowed cult members for provided level
  function getLevelLimit(level: Int): Int
    {
      switch (level)
        {
          case 3:
            return 1;
          case 2:
            return 3;
          case 1:
            return 10;
          default:
            return -1;
        }
    }

// checks if cult has room for another member at provided level
  public function canAddMemberAtLevel(level: Int): Bool
    {
      var limit = getLevelLimit(level);
      if (limit < 0)
        return true;
      return countMembers(level) < limit;
    }

  function get_leader(): AIData
    {
      return members[0];
    }

// clears cultists from provided area
  function clearCultistsInArea(area: AreaGame, remove: Bool)
    {
      if (area == null)
        return;
      var list = [];
      for (ai in area.getAllAI())
        if (ai.isCultist && ai.cultID == id)
          list.push(ai);
      for (ai in list)
        {
          ai.isCultist = false;
          ai.cultID = 0;
          if (remove)
            area.removeAI(ai);
        }
    }

// clears cultists from all habitats
  function clearCultistsInHabitats()
    {
      var region = game.region;
      if (region == null)
        return;
      var habitats = region.getHabitatsList();
      for (habitatArea in habitats)
        {
          if (habitatArea == game.area)
            continue;
          clearCultistsInArea(habitatArea, true);
        }
    }

// helper function to get all active trade effects
  function getTradeEffects(): Array<Effect>
    {
      var list = [];
      
      // collect trade effects from cult
      for (e in effects)
        if (e.type == CULT_EFFECT_INCREASE_TRADE_COST ||
            e.type == CULT_EFFECT_DECREASE_TRADE_COST)
          list.push(e);
      
      // collect trade effects from ordeals
      for (ordeal in ordeals.list)
        for (e in ordeal.effects)
          if (e.type == CULT_EFFECT_INCREASE_TRADE_COST ||
              e.type == CULT_EFFECT_DECREASE_TRADE_COST)
            list.push(e);
      
      return list;
    }

// get trade cost with effect modifiers
  public function getTradeCost(): Int
    {
      var base = 10000;
      var cost = base;
      
      // apply trade effects
      for (e in getTradeEffects())
        {
          if (e.type == CULT_EFFECT_INCREASE_TRADE_COST)
            {
              var incEff = cast(e, IncreaseTradeCost);
              var bonus = Std.int(base * incEff.percent / 100);
              if (bonus < 1) bonus = 1;
              cost += bonus;
            }
          else if (e.type == CULT_EFFECT_DECREASE_TRADE_COST)
            {
              var decEff = cast(e, DecreaseTradeCost);
              var minus = Std.int(base * decEff.percent / 100);
              if (minus < 1) minus = 1;
              cost -= minus;
            }
        }

      // ensure cost doesn't go below 1
      if (cost < 1)
        cost = 1;

      return cost;
    }

// get trade resource cost with effect modifiers
  public function getTradeResourceCost(): Int
    {
      var base = 3;
      var cost = base;
      
      // apply trade effects
      for (e in getTradeEffects())
        {
          if (e.type == CULT_EFFECT_INCREASE_TRADE_COST)
            {
              var incEff = cast(e, IncreaseTradeCost);
              var bonus = Std.int(base * incEff.percent / 100);
              if (bonus < 1) bonus = 1;
              cost += bonus;
            }
          else if (e.type == CULT_EFFECT_DECREASE_TRADE_COST)
            {
              var decEff = cast(e, DecreaseTradeCost);
              var minus = Std.int(base * decEff.percent / 100);
              if (minus < 1) minus = 1;
              cost -= minus;
            }
        }

      // ensure cost doesn't go below 1
      if (cost < 1)
        cost = 1;

      return cost;
    }

// trade money for other power types
  public function trade(powerType: String): Bool
    {
      if (effects.has(CULT_EFFECT_NOTRADE))
        {
          game.actionFailed('Trade rites are sealed at the moment.');
          return false;
        }

      var cost = getTradeCost();
      if (resources.money < cost)
        {
          game.actionFailed('Not enough money for trade.');
          return false;
        }

      // deduct money
      resources.money -= cost;

      // add power based on type
      resources.inc(powerType, 1);

      log('trades ' + Const.col('cult-power', cost) + Icon.money + ' for ' +
        Const.col('cult-power', '1 ') +
        powerType + ' power');
      return true;
    }

// trade resources between different power types
  public function tradeResource(from: String, to: String): Bool
    {
      if (effects.has(CULT_EFFECT_NOTRADE))
        {
          game.actionFailed('Trade rites are sealed at the moment.');
          return false;
        }

      var cost = getTradeResourceCost();
      if (resources.get(from) < cost)
        {
          game.actionFailed('Not enough ' + from + ' resources for trade.');
          return false;
        }

      // deduct source resource
      resources.dec(from, cost);

      // add target resource
      resources.inc(to, 1);

      log('trades ' + Const.col('cult-power', cost) + ' ' +
        Const.col('cult-power', from) + ' for ' +
        Const.col('cult-power', '1 ') + to + ' power');
      return true;
    }

// called when player enters an area
  public function onEnterArea()
    {
      // check if current area is a mission area
      if (game.player.inMissionArea())
        {
          var mission = ordeals.getAreaMission(game.area);
          if (mission != null)
            {
              game.logsg('This area is a mission area for ' + mission.coloredName() + '.');
            }
        }
      recalc();
    }

// called when player leaves the area
  public function onLeaveArea()
    {
      recalc();
    }

// mission turn processing
  public function turnMission()
    {
      // find the mission for the current area
      var mission = ordeals.getAreaMission(game.area);
      if (mission != null &&
          !mission.isCompleted)
        mission.turn();
    }

  // add random bad effect to cult
  public function addRandomBadEffect(turns: Int)
    {
      // define effect classes and their constructor requirements
      var effectList: Array<Dynamic> = [
        { cls: NoTrade, power: false },
        { cls: LoseResource, power: true },
        { cls: DecreasePower, power: true },
        { cls: BlockCommunal, power: false },
        { cls: OrdealActions, power: false },
        { cls: DifficultHelp, power: false },
        { cls: DecreaseIncome, power: false },
        { cls: IncreaseTradeCost, power: false }
      ];

      // pick random effect
      var info = effectList[Std.random(effectList.length)];
      
      // create effect instance with appropriate constructor arguments
      var effect: Effect;
      if (info.power)
        {
          // effects that require power type
          var powerType = _CultPower.random();
          effect = Type.createInstance(info.cls, [game, turns, powerType]);
        }
      else effect = Type.createInstance(info.cls, [game, turns]);
      
      this.effects.add(effect);
      log('gains a new burden: ' + Const.col('cult-effect', effect.name));
    }

// returns true is cult or one of the ordeals has effect
  public function hasEffect(effectID: _CultEffectType): Bool
    {
      if (ordeals.hasEffect(effectID) ||
          effects.has(effectID))
        return true;
      return false;
    }
}
