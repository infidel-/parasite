// timed team base-defense ordeal
package cult.ordeals;

import cult.Ordeal;
import cult.missions.TeamBaseDefense as TeamBaseDefenseMission;
import game.Game;

class TeamBaseDefense extends Ordeal
{
  public var timer: Int;

  public function new(g: Game)
    {
      super(g);
      init();
      initPost(false);
      timer = 12;
      missions.push(new TeamBaseDefenseMission(game, cult.base.areaID));
    }

// init ordeal fields
  public override function init()
    {
      super.init();
      name = 'Defend Cor Nefandum (The Group)';
      type = ORDEAL_COMMUNAL;
      requiredMembers = 0;
      requiredMemberLevels = 0;
      actions = 0;
      note = Const.col('alert', 'The team attacks Cor Nefandum. If the timer expires, Cor Nefandum is destroyed and all will be lost.');
      timer = 12;
    }

// decrements timer and handles offscreen failure
  public override function turn()
    {
      timer--;
      if (cult.base != null)
        cult.base.activeDefenseTimer = timer;
      if (timer > 0)
        return;
      if (cult.base != null)
        {
          var heart = cult.base.getHeart();
          if (heart != null)
            cult.base.damageOrgan(heart, heart.health);
        }
      fail();
    }
}
