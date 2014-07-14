// game world manager - world events queue and handling

import World;

class WorldManager
{
  var game: Game;

  public function new(g: Game)
    {
      game = g;
    }


// ==================================================================================


// log shortcut
  inline function log(s: String)
    {
      // TODO: should there be any way for player to see this?
      // TODO: probably not, i can't think of a good reason
      game.log('DEBUG: ' + s, COLOR_WORLD);
    }
}
