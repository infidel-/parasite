// cult structure
package cult;

import game.AreaEvent;
import game.AreaGame;
import game.Game;
import ai.AI;
import ai.AIData;

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
  public var ordeals: CultOrdeals;
  var turnCounter: Int;

  public function new(g: Game)
    {
      game = g;
      id = (_maxID++);
      state = CULT_STATE_INACTIVE;
      members = [];
      isPlayer = false;
      name = 'Cult of Flesh';
      init();
      initPost(false);
    }

// init object before loading/post creation
// NOTE: new object fields should init here!
  public function init()
    {
      ordeals = new CultOrdeals(game);
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
    }

// called after load or creation
  public function initPost(onLoad: Bool)
    {
    }

// create cult (add leader)
  public function addLeader(ai: AI)
    {
      state = CULT_STATE_ACTIVE;
      ai.isNameKnown = true;
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
      ai.isNameKnown = true;
      ai.setCult(this);
      members.push(ai.cloneData());
      log('gains a new member: ' + ai.theName());
      recalc();
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
          // leader is dead
          if (members[0].id == aidata.id)
            destroy();
          members.remove(aidata);
          recalc();
        }

      else aidata.updateData(ai, 'on despawn');
    }

// leader is dead - destroy cult
  function destroy()
    {
      members = [];
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
      switch (action.id)
        {
          case 'callHelp':
            var ret = callHelpAction(action);
            if (!ret)
              return true;
        }
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
      return true;
    }

// get a list of free cultists
  function getFreeCultists(): Array<AIData>
    {
      // get a list of free cultists
      var free = [];
      for (ai in members)
        {
          // cultist already in this area
          var tmp = game.area.getAIByID(ai.id);
          if (tmp != null)
            continue;
          free.push(ai);
        }
      return free;
    }

// call for help
  function callHelpAction(action: _PlayerAction): Bool
    {
      // find what cultists are available
      var free = getFreeCultists();
      if (free.length == 0)
        {
          game.actionFailed('There are no more followers available.');
          return false;
        }
      game.log('You send out a call for help.');

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
 
// area manager: cultist arrives
  public function onArriveCultist(e: AreaEvent)
    {
      // find what cultists are still available
      var free = getFreeCultists();
      if (free.length == 0)
        return;

      // pick a cultist
      var idx = Std.random(free.length);
      var aidata = free[idx];
      game.debug(aidata.TheName() + ' has arrived.');
//          log('calls for help: ' + ai.theName());
      game.scene.sounds.play('ai-arrive-security', {
        x: e.x,
        y: e.y,
        canDelay: true,
        always: false,
      });

      // find location
      var loc = game.area.findLocation({
        near: { x: e.x, y: e.y },
        radius: 10,
        isUnseen: true
      });
      if (loc == null)
        {
          loc = game.area.findEmptyLocationNear(e.x, e.y, 5);
          if (loc == null)
            {
              Const.todo('Could not find free spot for spawn (cultist help)!');
              return;
            }
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
      if (members.length == 0)
        return;
      // cult needs 10 player turns to tick
      turnCounter += time;
      if (turnCounter < 10)
        return;
      turnCounter = 0;
      
      // increase resources by 1 for each 3 power of the same type
      resources.combat += Std.int(power.combat / 3);
      resources.media += Std.int(power.media / 3);
      resources.lawfare += Std.int(power.lawfare / 3);
      resources.corporate += Std.int(power.corporate / 3);
      resources.political += Std.int(power.political / 3);
      
      // money: collect 50% to resources
      resources.money += Std.int(power.money * 0.5);
      
      game.debug(name +
        ' turn: COM ' + resources.combat +
        ', MED ' + resources.media +
        ', LAW ' + resources.lawfare +
        ', COR ' + resources.corporate +
        ', POL ' + resources.political +
        ', MONEY ' + resources.money);
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
    }

// cult log
  public function log(text: String)
    {
      if (isPlayer)
        game.log('<span class=cult>' + name + '</span> ' + text + '.');
    }

// max cult size
  public function maxSize(): Int
    {
      return 10;
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
}
