package render.facility;

import render.facility.FacilityModel.Facility;

// where a clue document may NOT be dropped, because something the renderer draws is already lying
// there.
//
// game.AreaGame.initSpawnPoints builds `clueSpawnPoints` out of the saved grid alone: every bench or
// desk tile with no OBJECT on it. That is the whole of what the game side can see, and two families
// in this package own such cells while stamping nothing it could have seen — render.facility
// .FacilitySink takes one free edge cell of every bench block for its basin and tap, and
// render.facility.FacilityWork stands a workstation on an office desk cell. Both are render-only by
// design (no atlas frame, no cell taken, nothing persisted), so a document spawned later in the turn
// loop landed through a basin or through a monitor.
//
// SO IT PRUNES THE LIST RATHER THAN RE-DERIVING IT, and that is the cheap half of this. The list is
// an ordinary array on the area that the save already carries, both predicates are pure functions of
// the same saved grid every other pass here reads, and dropping a cell is idempotent — so one walk on
// area entry fixes an area built before any of this existed and costs nothing on the next entry.
//
// AND IT IS A PRUNE AND NEVER A CLAIM: nothing is added back. A cell this drops was never a legal
// spot; the generator is what has to leave enough legal ones, which is why it keeps clear worktop
// cells aside (game.FacilityAreaGenerator.clearTableSpots)
class FacilityClues
{
// drop every clue spot the worktop families have dressed. returns how many went, for __facility()
  public static function prune(m:Facility, area:game.AreaGame):Int
    {
      var n = 0;
      var i = area.clueSpawnPoints.length - 1;
      while (i >= 0)
        {
          var p = area.clueSpawnPoints[i];
          if (m.tableSink[p.y][p.x] ||
              FacilityWork.at(m, p.x, p.y) != null)
            {
              area.clueSpawnPoints.splice(i, 1);
              n++;
            }
          i--;
        }
      return n;
    }
}
