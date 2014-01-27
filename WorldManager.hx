// game world manager - world events queue and handling

import World;

class WorldManager
{
  var game: Game;

  public function new(g: Game)
    {
      game = g;
    }


// event: body has been discovered by authorities
// pts - amount of organ points this body has
  public function onBodyDiscovered(area: WorldArea, pts: Int)
    {
      area.alertness += 1;
      area.interest += pts;
      if (pts > 0)
        log('Authorities have discovered a body with some weird anomalies.');
    }


// ==================================================================================


// log shortcut
  inline function log(s: String)
    {
      // TODO: should there be any way for player to see this?
      // TODO: probably not, i can't think of a good reason
      game.log('DEBUG: ' + s, Const.COLOR_WORLD);
    }
}
