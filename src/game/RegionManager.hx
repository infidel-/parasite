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
      var name = ai.name.realCapped;
      // a timeline NPC is silenced for good: it dies, as the log says, and is never spawned again
      var npc = ai.npc;
      if (npc != null)
        {
          npc.isDead = true;
          npc.statusKnown = true;
          log(T('{name} had suffered a fatal accident.', { name: name }));
        }
      else if (ai.wasInvaded)
        {
          var tmp = [
            T('{name} is claiming to have been possessed by an angel.', { name: name }),
            T('{name} is claiming to be the subject of experiments conducted by aliens.', { name: name }),
            T('{name} has died under mysterious circumstances.', { name: name }),
            T('{name} had to be committed to a mental institution after having a nervous breakdown.', { name: name }),
            T('{name} has apparently taken their own life after having a mental breakdown.', { name: name }),
            ];
          log(tmp[Std.random(tmp.length)]);
        }
      else if (ai.wasAttached)
        log(T('{name} is claiming to be the subject of a weird animal attack.', { name: name }));
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
