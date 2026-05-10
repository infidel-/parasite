// timed team base-defense ordeal
package cult.ordeals;

import cult.ProfaneOrdeal;
import cult.missions.TeamBaseDefense as TeamBaseDefenseMission;
import game.Game;

class TeamBaseDefense extends ProfaneOrdeal
{
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
      requiredMembers = 0;
      requiredMemberLevels = 0;
      actions = 0;
      note = Const.col('alert', 'The team attacks Cor Nefandum. If the timer expires, Cor Nefandum is destroyed and all will be lost.');
      timer = 12;
    }

// syncs base status timer after central profane timer tick
  public override function onTimerTick()
    {
      if (cult.base != null)
        cult.base.activeDefenseTimer = timer;
    }

// destroys Cor Nefandum when timer expires
  override function onFail()
    {
      if (cult.base != null)
        {
          var heart = cult.base.getHeart();
          if (heart != null)
            cult.base.damageOrgan(heart, heart.health);
        }
    }
}
