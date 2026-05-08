// mission to retrieve the Necronomicon
package cult.missions;

import cult.Mission;
import game.Game;

class Necronomicon extends Mission
{
  public var spawned: Bool;

  public function new(g: Game)
    {
      super(g);
      init();
      initPost(false);
      var area = game.region.getRandom({
        noMission: true,
        noEvents: true,
        noThrow: true,
        type: AREA_CORP
      });
      if (area == null)
        area = game.region.getRandom({
          noMission: true,
          noEvents: true,
          noThrow: true,
          type: AREA_FACILITY
        });
      if (area != null)
        {
          x = area.x;
          y = area.y;
        }
    }

// init mission fields
  public override function init()
    {
      super.init();
      type = MISSION_COMBAT;
      name = 'Necronomicon';
      note = 'Recover the forbidden book and leave with it.';
      spawned = false;
    }

// spawn the book in mission area
  public override function turn()
    {
      if (spawned ||
          game.location != LOCATION_AREA ||
          game.area == null ||
          game.area.x != x ||
          game.area.y != y)
        return;
      var loc = game.area.findUnseenEmptyLocation();
      if (loc == null ||
          loc.x < 0)
        loc = game.area.findEmptyLocationNear(game.playerArea.x,
          game.playerArea.y, 5);
      if (loc == null)
        return;
      new objects.Necronomicon(game, game.area.id, loc.x, loc.y, id);
      spawned = true;
      game.logsg('The Necronomicon is somewhere nearby.');
    }
}
