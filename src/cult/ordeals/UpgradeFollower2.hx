package cult.ordeals;

import game.Game;
import jsui.Choice._ChoiceParams;
import Const;
import _CultEvent;
import cult.Cult;
import cult.UpgradeFollowerEvents;
import _PlayerAction;

class UpgradeFollower2 extends UpgradeFollower
{
  public function new(g: Game, targetID: Int)
    {
      super(g, targetID, 2);
      // add two random free level 2+ members to ordeal (excluding target)
      var free = cult.getFreeMembers(2, true);
      var avail = [];
      for (id in free)
        if (id != targetID)
          avail.push(id);
      
      var idx1 = Std.random(avail.length);
      var h1 = avail[idx1];
      avail.splice(idx1, 1);
      var idx2 = Std.random(avail.length);
      var h2 = avail[idx2];
      addMembers([h1, h2]);
    }

// init object before loading/post creation
  public override function init()
    {
      super.init();
      name = 'Elevate the faithful II';
      type = ORDEAL_COMMUNAL;
      requiredMembers = 2;
      requiredMemberLevels = 1;
      actions = requiredMembers;
      note = 'Two seasoned devotees marshal greater influence to raise a chosen member to highest power.';

      var targetMember = null;
      for (m in cult.members)
        {
          if (m.id == targetID)
            {
              targetMember = m;
              break;
            }
        }

      power.money = 30000;
      if (targetMember != null)
        {
          var jobInfo = game.jobs.getJobInfo(targetMember.job);
          if (jobInfo != null)
            power.setByGroup(jobInfo.group, 2);
        }
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

      // pick upgrade event
      var jobInfo = game.jobs.getJobInfo(targetMember.job);
      var event = UpgradeFollowerEvents.getRandom(jobInfo.group);
      var payload = {
        event: event,
        game: game,
        cult: cult
      };

      // create choice window
      var params: _ChoiceParams = {
        title: Const.col('occasio', 'Occasio') + ': ' + event.title,
        text: event.text,
        choices: [],
        buttons: [],
        src: payload,
        textClass: 'window-occasio-text',
        // choiceID is 1-3
        f: function(src: Dynamic, choiceID: Int)
          {
            var data: { event: _CultEvent, game: Game, cult: Cult } = cast src;
            var choice = data.event.choices[choiceID - 1];
            game.log('You chose ' + Const.col('gray', choice.button) + ' in occasio ' + Const.col('occasio', event.title) + '.');
            choice.f(data.game, data.cult, targetID);
          }
      };
      for (choice in event.choices)
        {
          params.buttons.push(choice.button);
          params.choices.push(choice.text);
        }

      game.ui.event({
        type: UIEVENT_STATE,
        state: UISTATE_CHOICE,
        obj: params
      });
      game.ui.closeWindow();
    }

// static method to add upgrade2 action to actions array
  public static function initiateAction(cult: Cult, actions: Array<_PlayerAction>): Void
    {
      // check if there are enough free level 2 members for second upgrade
      var free = cult.getFreeMembers(2, true);
      if (free.length < 3 ||
          !cult.canAddMemberAtLevel(3))
        return;
      
      actions.push({
        id: 'upgrade2',
        type: ACTION_CULT,
        name: 'Elevate the faithful II',
        energy: 0,
        obj: { submenu: 'upgrade2' }
      });
    }

// static method to get upgrade2 submenu actions
  public static function getUpgrade2Actions(cult: Cult, game: Game): Array<_PlayerAction>
    {
      var actions: Array<_PlayerAction> = [];
      
      actions.push({
        id: 'back',
        type: ACTION_CULT,
        name: 'Back',
        energy: 0,
        obj: { submenu: 'back' }
      });
      
      var free = cult.getFreeMembers(2, true);
      if (free.length < 3)
        return actions;
      
      for (mid in free)
        {
          var m = cult.getMemberByID(mid);
          if (m == null)
            continue;
          
          var name = m.TheName();
          
          // check if member can be upgraded
          var job = game.jobs.getJobInfo(m.job);
          var canUpgrade = (job != null &&
            job.level < 3 &&
            game.jobs.getNextJobLevel(job.group, m.job) != null);
          
          var action: _PlayerAction = {
            id: 'upgrade2',
            type: ACTION_CULT,
            name: name,
            energy: 0,
            obj: { targetID: mid }
          };
          
          if (!canUpgrade)
            {
              action.name += Const.smallgray(' [cannot elevate]');
              action.f = function() {
                game.actionFailed('This member cannot be elevated further.');
              };
            }
          
          actions.push(action);
        }
      
      return actions;
    }
}
