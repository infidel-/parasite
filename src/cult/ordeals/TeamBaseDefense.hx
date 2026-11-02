// timed team base-defense ordeal
package cult.ordeals;

import l10n.Loc;
import cult.ProfaneOrdeal;
import cult.missions.TeamBaseDefense as TeamBaseDefenseMission;
import game.Game;

class TeamBaseDefense extends ProfaneOrdeal
{
  // the note, also on load: a 1.0 save holds it as colored English, which no lookup finds
  static var NOTE = N('The team attacks Cor Nefandum. If the timer expires, Cor Nefandum is destroyed and all will be lost.');
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
      name = N('Defend Cor Nefandum (The Group)');
      requiredMembers = 0;
      requiredMemberLevels = 0;
      actions = 0;
      note = NOTE;
      timer = 12;
    }

// the note, in the alert color
  public override function getNote(): String
    {
      return Const.col('alert', Loc.tr(NOTE));
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
