// AI for military officers

package ai;

import game.Game;

class OfficerAI extends HumanAI
{
  public function new(g: Game, vx: Int, vy: Int)
    {
      super(g, vx, vy);
      init();
      inventory.addID('pistol');
      skills.addID(SKILL_PISTOL, 40 + Std.random(25));
      // officers talk for a living: better chat skills than the police
      if (Std.random(100) < 80)
        skills.addID(SKILL_PSYCHOLOGY, 30 + Std.random(15));
      if (Std.random(100) < 70)
        skills.addID(SKILL_COERCION, 30 + Std.random(15));
      if (Std.random(100) < 50)
        skills.addID(SKILL_DECEPTION, 25 + Std.random(15));
      if (Std.random(100) < 40)
        skills.addID(SKILL_COAXING, 25 + Std.random(15));
      initPost(false);
    }

// init object before loading/post creation
  public override function init()
    {
      super.init();
      type = 'officer';
      name.unknown = 'officer';
      name.unknownCapped = 'Officer';
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
