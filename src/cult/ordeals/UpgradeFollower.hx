// upgrade follower ordeal - elevate the faithful
package cult.ordeals;

import game.Game;
import ai.*;
import cult.Cult;
import cult.Ordeal;

class UpgradeFollower extends Ordeal
{
  public var targetID: Int;

  public function new(g: Game, targetID: Int, level: Int)
    {
      super(g);
      this.targetID = targetID;
      init();
      initPost(false);

      // child classes may call this too, so only add members if level 1
      if (level != 1)
        return;

      // add two random free members of level 1 to ordeal (excluding target)
      var free = cult.getFreeMembers(1);
      var avail = [];
      for (id in free)
        {
          if (id != targetID)
            avail.push(id);
        }
      
      if (avail.length >= 2)
        {
          // shuffle and take first 2
          var shuf = [];
          for (id in avail)
            shuf.push(id);
          shuf.sort(function(a, b) return Std.random(3) - 1);
          addMembers([shuf[0], shuf[1]]);
        }
      else if (avail.length >= 1)
        {
          // only one available, use it
          addMembers([avail[0]]);
        }
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

      // get next job level
      var nextJob = game.jobs.getNextJobLevel(jobInfo.group, member.job);
      if (nextJob == null)
        return false;

      // apply upgrade
      var jobData = game.jobs.rollJobInfo([nextJob]);
      member.job = jobData.name;
      member.income = jobData.income;
      cult.log('member ' + member.TheName() + ' has been elevated to level ' + nextJob.level);
      cult.recalc();
      return true;
    }
}
