// upgrade follower II ordeal
package cult;

import game.Game;
import ai.*;
import jsui.Choice._ChoiceParams;

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

// called after load or creation
  public override function initPost(onLoad: Bool)
    {
      super.initPost(onLoad);
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

      var params: _ChoiceParams = {
        title: Const.col('occasio', 'Occasio: ') + 'Test Rite',
        text: 'A moment of Occasio follows the ascension, as whispered prayers coil around the sanctum. The faithful gather to debate how best to wield the surge of favor, weighing omen, silver, and secrecy in equal measure. Their verdict will ripple through the cult\'s next hundred turns, shaping how devotion is tithed and where influence takes root.',
        choices: [
          'Invoke the blood hymn to gain occult insight.',
          'Disperse alms among sympathisers to secure wealth.',
          'Hold a clandestine vigil to steady political ties.'
        ],
        buttons: [
          'Blood Hymn',
          'Golden Tithe',
          'Silent Vigil'
        ],
        src: this,
        textClass: 'window-occasio-text',
        f: function(src: Dynamic, choiceID: Int)
          {
            var ordeal: UpgradeFollower2 = cast src;
            ordeal.cult.log('Occasio choice selected: ' + choiceID);
          }
      };

      game.ui.event({
        type: UIEVENT_STATE,
        state: UISTATE_CHOICE,
        obj: params
      });
      game.ui.closeWindow();
    }
}
