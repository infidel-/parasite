// cult structure
package cult;

import game.Game;
import ai.AI;

class Cult
{
  public var game: Game;
  public var id: Int;
  public static var _maxID: Int = 1; // current max ID
  public var state: _CultState;
  // NOTE: cult members will exist both in world and in this list
  public var members: Array<AI>;
  public var leader(get, null): AI;
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
      members.push(ai);
      ai.setCult(this);
      log('gains a leader: ' + ai.theName());
    }

// cult log
  public function log(text: String)
    {
      if (isPlayer)
        game.log(name + ' ' + text + '.');
    }

// add new member
  public function addMember(ai: AI)
    {
      members.push(ai);
      ai.setCult(this);
      log('gains a new member: ' + ai.theName());
    }

// cult turn
  public function turn()
    {
      
    }

// max cult size
  public function maxSize(): Int
    {
      return 5;
    }

  function get_leader(): AI
    {
      return members[0];
    }
}
