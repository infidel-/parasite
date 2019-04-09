import game.Player;

typedef _PlayerAction =
{
  id: String, // action id
  type: _PlayerActionType, // action type
  name: String, // action name
  ?energy: Int, // energy to complete

  ?obj: Dynamic, // bound object to act on
  // func that returns energy activation cost (should return < 0 if action is not available)
  ?energyFunc: Player -> Int,
  ?key: Int, // keyboard shortcut
}
