// timed base-defense ordeal
package cult.ordeals;

import cult.Ordeal;
import cult.missions.BaseDefense as BaseDefenseMission;
import game.Game;

class BaseDefense extends Ordeal
{
  public var timer: Int;
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
      name = 'Defend Cor Nefandum';
      type = ORDEAL_COMMUNAL;
      requiredMembers = 0;
      requiredMemberLevels = 0;
      actions = 0;
      note = Const.col('alert', 'If the timer expires, Cor Nefandum is destroyed and all will be lost.');
      timer = 12;
      cultID = -1;
    }

// get custom name for display
  public override function customName(): String
    {
      var rival = game.getCultByID(cultID);
      if (rival != null)
        return name + ' - ' + rival.customName();
      return name;
    }

// called after load or creation
  public override function initPost(onLoad: Bool)
    {
      var rival = game.getCultByID(cultID);
      if (rival != null)
        note = Const.col('alert', rival.customName() +
          ' attacks Cor Nefandum. If the timer expires, Cor Nefandum is destroyed and all will be lost.');
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
