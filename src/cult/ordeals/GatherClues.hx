// gather clues ordeal - haruspicy
package cult.ordeals;

import game.Game;
import ai.*;
import cult.Ordeal;

class GatherClues extends Ordeal
{
  public var memberType: String; // job type of the member

  public function new(g: Game)
    {
      super(g);
      // get one random free level 3 member
      var free = cult.getFreeMembers(3, true);
      var mid = free[Std.random(free.length)];
      var m = cult.getMemberByID(mid);
      
      // get member job group and convert to string
      var job = game.jobs.getJobInfo(m.job);
      this.memberType = (job != null ? game.jobs.groupToName(job.group) : 'combat');
      addMembers([mid]);
      
      init();
      initPost(false);
    }

// init object before loading/post creation
  public override function init()
    {
      super.init();
      name = 'Anthropomancy';
      type = ORDEAL_COMMUNAL;
      requiredMembers = 1;
      requiredMemberLevels = 3;
      actions = requiredMembers;
      note = 'A master haruspex reads the entrails of fate to uncover hidden knowledge.';
      
      // set power based on member type
      power.inc(memberType, 3);
      power.money = 50000;
    }

// called after load or creation
  public override function initPost(onLoad: Bool)
    {
      super.initPost(onLoad);
    }

// handle member death
  public override function onDeath(aidata: AIData)
    {
      fail();
    }

// handle successful completion
  public override function onSuccess()
    {
      // x3: pick a timeline event and learn clues
      for (i in 0...3)
        {
          var event = game.timeline.getRandomLearnableEvent();
          if (event != null)
            game.timeline.learnClues(event, false);
        }
    }
}
