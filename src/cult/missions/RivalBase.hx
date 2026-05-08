// mission to destroy a simplified rival cult base
package cult.missions;

import cult.Mission;
import game.Game;
import objects.RivalSanctum;

class RivalBase extends Mission
{
  public var rivalCultID: Int;
  public var spawned: Bool;

  public function new(g: Game, rivalCultID: Int, areaID: Int)
    {
      super(g);
      init();
      initPost(false);
      this.rivalCultID = rivalCultID;
      this.areaID = areaID;
      markerAreaID = areaID;
    }

// init mission fields
  public override function init()
    {
      super.init();
      type = MISSION_COMBAT;
      name = 'Rival Base';
      note = 'Destroy the rival sanctum.';
      rivalCultID = -1;
      spawned = false;
    }

// spawn sanctum and defenders
  public override function turn()
    {
      if (spawned ||
          game.location != LOCATION_AREA ||
          game.area == null ||
          game.area.id != areaID)
        return;
      spawned = true;
      var loc = game.area.findEmptyLocationNear(game.playerArea.x,
        game.playerArea.y, 6);
      if (loc == null)
        loc = game.area.findEmptyLocation();
      new RivalSanctum(game, game.area.id, loc.x, loc.y, id);
      for (i in 0...3)
        {
          var spawn = game.area.findEmptyLocationNear(loc.x, loc.y, 5);
          if (spawn == null)
            continue;
          var ai = game.area.spawnAI(i == 0 ? 'security' : 'thug',
            spawn.x, spawn.y);
          ai.isGuard = true;
          ai.guardTargetX = loc.x;
          ai.guardTargetY = loc.y;
        }
    }

// marks rival destroyed
  public override function onSuccess()
    {
      var rival = game.getCultByID(rivalCultID);
      rival.state = CULT_STATE_DEAD;
    }
}
