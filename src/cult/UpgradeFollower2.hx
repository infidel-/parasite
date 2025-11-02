package cult;

import game.Game;
import jsui.Choice._ChoiceParams;
import Const;
import _CultEvent;
import _CultEventChoice;
import cult.Cult;

class UpgradeFollower2 extends UpgradeFollower
{
  public function new(g: Game, targetID: Int)
    {
      super(g, targetID);
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
        f: function(src: Dynamic, choiceID: Int)
          {
            var data: { event: _CultEvent, game: Game, cult: Cult } = cast src;
            var choice = data.event.choices[choiceID];
            choice.f(data.game, data.cult);
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
}
