// upgrade follower ordeal - elevate the faithful
package cult;

import game.Game;
import ai.*;

class UpgradeFollower extends Ordeal
{
  public var targetID: Int;

  public function new(g: Game, targetID: Int)
    {
      super(g);
      this.targetID = targetID;
      init();
      initPost(false);
    }

// init object before loading/post creation
  public override function init()
    {
      super.init();
      name = 'Elevate the faithful';
      type = ORDEAL_COMMUNAL;
      requiredMembers = 2;
      requiredMemberLevels = 1;
      actions = requiredMembers;
      note = 'Two pious followers pour their devotion to elevate a chosen member to a seat of greater influence.';

      // set power requirements based on target member's group
      var targetMember = null;
      for (m in cult.members)
        {
          if (m.id == targetID)
            {
              targetMember = m;
              break;
            }
        }

      power.money = 5000;
      if (targetMember != null)
        {
          // civilians will only require money
          var jobInfo = game.jobs.getJobInfo(targetMember.job);
          if (jobInfo != null)
            power.setByGroup(jobInfo.group, 1);

          else power.money = 5000;
        }
    }

// called after load or creation
  public override function initPost(onLoad: Bool)
    {
      super.initPost(onLoad);
    }

// get list of cultist IDs locked by this ordeal
  public override function getLockedCultists(): Array<Int>
    {
      // include both the target member and the members doing the upgrade
      var locked = members.copy();
      if (locked.indexOf(targetID) == -1)
        locked.push(targetID);
      return locked;
    }

// handle member death
  public override function onDeath(aidata: AIData)
    {
      fail();
    }

// handle successful completion
  public override function onSuccess()
    {
      // find target member
      var targetMember = cult.getMemberByID(targetID);
      if (targetMember == null)
        return;

      // upgrade member level
      UpgradeFollower.upgradeMember(game, cult, targetMember);
    }

// get custom name for display
  public override function customName(): String
    {
      var aidata = cult.getMemberByID(targetID);
      return name + ' - ' + aidata.TheName();
    }

// upgrade member to next job level if available
  public static function upgradeMember(game: Game, cult: Cult, member: AIData): Bool
    {
      var jobInfo = game.jobs.getJobInfo(member.job);
      if (jobInfo == null ||
          jobInfo.level >= 3)
        return false;

      var nextLevel = jobInfo.level + 1;
      var job = game.jobs.getJobByGroupAndLevel(jobInfo.group, nextLevel);
      if (job == null)
        return false;

      var jobData = game.jobs.rollJobInfo([job]);
      member.job = jobData.name;
      member.income = jobData.income;
      cult.log('member ' + member.TheName() + ' has been elevated to level ' + nextLevel);
      cult.recalc();
      return true;
    }
}
