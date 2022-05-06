// game fsm

package game;

class FSM<StateType, FlagType> extends _SaveObject
{
  var fsmName: String;
  var game: Game;
  public var state(default, set): StateType;
//  var fsmFlags: haxe.ds.EnumValueMap<FlagType, Bool>;


  public function new(g: Game, n: String)
    {
      game = g;
      fsmName = n;
//      fsmFlags = new haxe.ds.EnumValueMap();
    }


/*
// returns true, if FSM has this flag set
  public inline function hasFlag(f: FlagType): Bool
    {
      return (fsmFlags.get(f) ? true : false);
    }


// sets a flag
  public function setFlag(f: FlagType, v: Bool)
    {
      if (v)
        fsmFlags.set(f, true);
      else fsmFlags.remove(f);
    }
*/


  function set_state(v: StateType): StateType
    {
      game.debug('FSM ' + fsmName + ' set state: ' + v);
      state = v;
      return v;
    }
}
