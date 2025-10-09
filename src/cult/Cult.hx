// cult structure
package cult;

import game.AreaEvent;
import game.AreaGame;
import game.Game;
import ai.AI;
import ai.AIData;

class Cult
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

  public function new(g: Game)
    {
      game = g;
      id = (_maxID++);
      state = CULT_STATE_INACTIVE;
      members = [];
      isPlayer = false;
      name = 'Cult of Flesh';
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
    }

// add new member
  public function addMember(ai: AI)
    {
      ai.isNameKnown = true;
      ai.setCult(this);
      members.push(ai.cloneData());
      log('gains a new member: ' + ai.theName());
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
  public function action(action: _PlayerAction)
    {
      switch (action.id)
        {
          case 'callHelp':
            var ret = callHelpAction(action);
            if (!ret)
              return;
        }
      game.playerArea.actionPost(); // post-action call
    }

// returns true if player can call for help
  public function canCallHelp(): Bool
    {
      if (state != CULT_STATE_ACTIVE)
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
  public function turn()
    {
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
      return 5;
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
