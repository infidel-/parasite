// kill mission sample
package cult.missions;

import game.Game;
import cult.Mission;
import ai.*;
import _AreaType;

class Kill extends Mission
{
  public var target: AIData;

  public function new(g: Game)
    {
      super(g);
      init();
      initPost(false);
    }

// init object before loading/post creation
  public override function init()
    {
      super.init();
      type = MISSION_KILL;
      name = 'Eliminate Target';
      note = 'A specific target must be eliminated.';
      
      // create random civilian AI and clone its data
      var ai = new CivilianAI(game, 0, 0);
      target = ai.cloneData();
      target.isNameKnown = true;
      
      // pick random area position
      var area = game.region.getRandomWithType(AREA_CITY_HIGH, true);
      if (area != null)
        {
          x = area.x;
          y = area.y;
        }
    }

// get custom name for display
  public override function customName(): String
    {
      if (target != null)
        return name + ' - ' + target.TheName();
      return name;
    }
}
