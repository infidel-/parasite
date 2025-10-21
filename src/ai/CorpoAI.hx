// AI for corpo workers

package ai;

import game.Game;

class CorpoAI extends HumanAI
{
  public function new(g: Game, vx: Int, vy: Int)
    {
      super(g, vx, vy);
      init();
      skills.addID(SKILL_COMPUTER, 20 + Std.random(30));
      inventory.addID('smartphone');
      initPost(false);
    }

// init object before loading/post creation
  public override function init()
    {
      super.init();
      type = 'corpo';
      name.unknown = 'office worker';
      name.unknownCapped = 'Office worker';
      soundsID = 'civilian';
      var jobData = game.jobs.getRandom(type);
      job = jobData.name;
      income = jobData.income;
    }

// called after load or creation
  public override function initPost(onLoad: Bool)
    {
      super.initPost(onLoad);
    }

// event: on state change
  public override function onStateChange()
    {
      onStateChangeDefault();
    }
}
