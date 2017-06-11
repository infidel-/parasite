// world region manager - region events queue and handling

package game;

import ai.AI;

class RegionManager
{
  var game: Game;

  public function new(g: Game)
    {
      game = g;
    }


// event: human that hosted or was attached to the parasite, got away
  public function onHostDiscovered(area: AreaGame, ai: AI)
    {
      game.group.raisePriority(__Math.hostDiscovered(ai));
      if (ai.npc != null)
        log(ai.name.realCapped + ' had suffered a fatal accident.');
      else if (ai.wasInvaded)
        {
          var tmp = [
            ' is claiming to have been possessed by an angel.',
            ' is claiming to be the subject of experiments conducted by aliens.',
            ' has died under mysterious circumstances.',
            ' had to be committed to a mental institution after having a nervous breakdown.',
            ' has apparently taken their own life after having a mental breakdown.',
            ];
          log(ai.name.realCapped + tmp[Std.random(tmp.length)]);
        }
      else if (ai.wasAttached)
        log(ai.name.realCapped + ' is claiming to be the subject of a weird animal attack.');
    }


// event: body has been discovered by authorities
// pts - amount of organ points this body has
  public function onBodyDiscovered(area: AreaGame, pts: Int)
    {
      area.alertness += 10;
      game.group.raisePriority(pts);
      if (pts > 0)
        log('Authorities have discovered a body with some weird anomalies.');
    }


// event: multiple bodies have been discovered (called on leaving area)
// pts - amount of organ points this body has
  public function onBodiesDiscovered(area: AreaGame, bodies: Int, pts: Int)
    {
      area.alertness += bodies * 10;
      game.group.raisePriority(pts);
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
