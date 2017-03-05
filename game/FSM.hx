// game fsm

package game;

class FSM<StateType>
{
  var fsmName: String;
  var game: Game;
  public var state(default, set): StateType;


  public function new(g: Game, n: String)
    {
      game = g;
      fsmName = n;
    }


  function set_state(v: StateType): StateType
    {
      game.debug('FSM ' + fsmName + ' set state: ' + v);
      state = v;
      return v;
    }
}
