// cult structure
package cult;

import game.Game;
import ai.AI;
import ai.AIData;

class Cult
{
  public var game: Game;
  public var id: Int;
  public static var _maxID: Int = 0; // current max ID
  public var state: _CultState;
  // NOTE: cult members will exist both in world and in this list
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
      ai.setCult(this);
      members.push(ai.cloneData());
      log('gains a leader: ' + ai.theName());
    }

// add new member
  public function addMember(ai: AI)
    {
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

      else aidata.updateData(ai);
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
    }

// cult turn
  public function turn()
    {
    }

// cult log
  public function log(text: String)
    {
      if (isPlayer)
        game.log(name + ' ' + text + '.');
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
}
