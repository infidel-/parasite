// world region manager - region events queue and handling

package game;

class RegionManager
{
  var game: Game;

  public function new(g: Game)
    {
      game = g;
    }


// event: body has been discovered by authorities
// pts - amount of organ points this body has
  public function onBodyDiscovered(area: AreaGame, pts: Int)
    {
      area.alertness += 1;
      area.interest += pts;
      if (pts > 0)
        log('Authorities have discovered a body with some weird anomalies.');
    }


// event: multiple bodies have been discovered (called on leaving area) 
// pts - amount of organ points this body has
  public function onBodiesDiscovered(area: AreaGame, bodies: Int, pts: Int)
    {
      area.alertness += bodies;
      area.interest += pts;
      if (pts > 0)
        log('Authorities have discovered multiple bodies with disturbing anomalies.');
    }


// ==================================================================================


// log shortcut
  inline function log(s: String)
    {
      // TODO: should there be any way for player to see this?
      // TODO: probably not, i can't think of a good reason
//      game.log('DEBUG: ' + s, COLOR_WORLD); // TODO: COLOR_REGION?
      game.debug(s); // TODO: COLOR_REGION?
    }
}
