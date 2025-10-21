// AI for soldiers 

package ai;

import game.Game;

class SoldierAI extends HumanAI
{
  public function new(g: Game, vx: Int, vy: Int)
    {
      super(g, vx, vy);
      init();
      if (Std.random(100) < 30)
        inventory.addID('assaultRifle');
      skills.addID(SKILL_RIFLE, 40 + Std.random(25));
      initPost(false);
    }

// init object before loading/post creation
  public override function init()
    {
      super.init();
      type = 'soldier';
      name.unknown = 'soldier';
      name.unknownCapped = 'Soldier';
      soundsID = 'soldier';
      isAggressive = true;
      var jobData = game.jobs.getRandom(type);
      job = jobData.name;
      income = jobData.income;
    }

// called after load or creation
  public override function initPost(onLoad: Bool)
    {
      super.initPost(onLoad);
    }
}
