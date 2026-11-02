// timed base-defense ordeal
package cult.ordeals;

import l10n.Loc;
import cult.ProfaneOrdeal;
import cult.missions.BaseDefense as BaseDefenseMission;
import game.Game;

class BaseDefense extends ProfaneOrdeal
{
  public var cultID: Int;

  public function new(g: Game, ?cultID: Int = -1)
    {
      super(g);
      init();
      this.cultID = cultID;
      initPost(false);
      timer = 12;
      missions.push(new BaseDefenseMission(game, cult.base.areaID, cultID));
    }

// init ordeal fields
  public override function init()
    {
      super.init();
      name = N('Defend Cor Nefandum');
      requiredMembers = 0;
      requiredMemberLevels = 0;
      actions = 0;
      note = N('If the timer expires, Cor Nefandum is destroyed and all will be lost.');
      timer = 12;
      cultID = -1;
    }

// get custom name for display
  public override function customName(): String
    {
      var rival = game.getCultByID(cultID);
      if (rival != null)
        return Loc.tr(name) + ' (' + rival.customName() + ')';
      return Loc.tr(name);
    }

// the note, naming the attacking rival cult
  public override function getNote(): String
    {
      var rival = game.getCultByID(cultID);
      return Const.col('alert', rival != null ?
        T('{rival} attacks Cor Nefandum. If the timer expires, Cor Nefandum is destroyed and all will be lost.', { rival: rival.customName() }) :
        Loc.tr(note));
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
