// upgrade follower ordeal - elevate the faithful
package cult.ordeals;

import game.Game;
import ai.*;
import cult.Cult;
import cult.Ordeal;
import _PlayerAction;

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
      if (level == 1)
        addRandomMembers({
          level: 1,
          amount: 2,
          excluding: targetID
        });
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

      power.money = 20000;
      if (targetMember != null)
        {
          // civilians will only require money
          var jobInfo = game.jobs.getJobInfo(targetMember.job);
          if (jobInfo != null)
            power.setByGroup(jobInfo.group, 3);
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

// static method to add upgrade action to actions array
  public static function initiateAction(cult: Cult, actions: Array<_PlayerAction>): Void
    {
      // check if there are enough free members for upgrade action
      var free = cult.getFreeMembers(1);
      if (free.length < 3 ||
          !cult.canAddMemberAtLevel(2)) // 2 + target
        return;
      
      // elevate the faithful action - opens submenu
      actions.push({
        id: 'upgrade',
        type: ACTION_CULT,
        name: 'Elevate the faithful',
        energy: 0,
        obj: { submenu: 'upgrade' }
      });
    }

// static method to get upgrade submenu actions
  public static function getUpgradeActions(cult: Cult, game: Game): Array<_PlayerAction>
    {
      var actions: Array<_PlayerAction> = [];
      
      // back button
      actions.push({
        id: 'back',
        type: ACTION_CULT,
        name: 'Back',
        energy: 0,
        obj: { submenu: 'back' }
      });
      
      // get free members of level 1
      var free = cult.getFreeMembers(1);
      for (mid in free)
        {
          // find member data
          var m = cult.getMemberByID(mid);
          if (m == null)
            continue;

          // only show level 1 members
          var job = game.jobs.getJobInfo(m.job);
          if (job == null ||
              job.level != 1)
            continue;
          
          actions.push({
            id: 'upgrade',
            type: ACTION_CULT,
            name: m.TheName(),
            energy: 0,
            obj: { targetID: mid }
          });
        }
      
      return actions;
    }
}
