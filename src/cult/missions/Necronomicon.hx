// mission to carry the Necronomicon out of the university library
//
// the book lies on the archive's lectern (game.LibraryAreaGenerator.enter lays it, ordeal or not).
// The library is the mission area, so it is locked until the host carries the book (canLeave); leaving
// with it completes the mission (onLeaveArea, from cult.Cult.onLeaveArea)
package cult.missions;

import cult.Mission;
import cult.ordeals.MetamorphosisPhaseI;
import game.AreaGame;
import game.Game;

class Necronomicon extends Mission
{
  public function new(g: Game)
    {
      super(g);
      init();
      initPost(false);
      var area = game.region.getRandom({
        noThrow: true,
        type: AREA_LIBRARY
      });
      if (area != null)
        {
          areaID = area.id;
          x = area.x;
          y = area.y;
        }
    }

// init mission fields
  public override function init()
    {
      super.init();
      type = MISSION_COMBAT;
      name = N('Necronomicon');
      note = N('Take the forbidden book from the university library and leave with it.');
    }

// the library lets the player out once the host carries the book
  public override function canLeave(): Bool
    {
      return MetamorphosisPhaseI.isHeld(game);
    }

// leaving the library with the book completes the mission
  public override function onLeaveArea(area: AreaGame)
    {
      if (area.id == areaID &&
          MetamorphosisPhaseI.isHeld(game))
        success();
    }
}
