// AI for smilers

package ai;

import scenario.GoalsAlienCrashLanding;
import scenario.GoalsAlienCrashLanding._MissionState;
import game.Game;

class SmilerAI extends HumanAI
{
  public function new(g: Game, vx: Int, vy: Int)
    {
      super(g, vx, vy);
      init();
      skills.addID(SKILL_COMPUTER, 20 + Std.random(30));
      skills.addID(SKILL_PSYCHOLOGY, 30 + Std.random(5));
      // 2/3 random chat skills
      var list: Array<_Skill> = [
        SKILL_DECEPTION,
        SKILL_COERCION,
        SKILL_COAXING
      ];
      for (i in 0...2)
        {
          var skillID = list[Std.random(list.length)];
          skills.addID(skillID, 30 + Std.random(20));
          list.remove(skillID);
        }
      inventory.addID('smartphone');
      game.goals.aiInit(this);
      initPost(false);
    }

// init object before loading/post creation
  public override function init()
    {
      super.init();
      type = 'smiler';
      name.unknown = 'office worker';
      name.unknownCapped = 'Office worker';
      soundsID = 'civilian';
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
