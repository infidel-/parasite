// Metamorphosis Phase I communal ordeal
package cult.ordeals;

import cult.Cult;
import cult.Ordeal;
import cult.missions.Necronomicon;
import game.Game;
import _PlayerAction;

class MetamorphosisPhaseI extends Ordeal
{
  public function new(g: Game)
    {
      super(g);
      init();
      initPost(false);
      var free = cult.getFreeMembers(3, true);
      if (free.length > 0)
        addMembers([ free[0] ]);
      missions.push(new Necronomicon(game));
    }

// init ordeal fields
  public override function init()
    {
      super.init();
      name = 'Metamorphosis, Phase I';
      type = ORDEAL_COMMUNAL;
      requiredMembers = 1;
      requiredMemberLevels = 3;
      actions = requiredMembers;
      note = 'A perfected follower seeks the most forbidden of knowledges.';
    }

// fail if bound member dies
  public override function onDeath(aidata: ai.AIData)
    {
      fail();
    }

// unlocks Phase II
  public override function onSuccess()
    {
      cult.metamorphosisPhaseIComplete = true;
      game.logsg('Metamorphosis Phase II is now possible.');
    }

// adds initiate action when level 3 follower exists
  public static function initiateAction(cult: Cult, actions: Array<_PlayerAction>)
    {
      if (cult.level != 1 ||
          cult.metamorphosisPhaseIComplete ||
          cult.countMembers(3) != 1)
        return;
      var free = cult.getFreeMembers(3, true);
      if (free.length < 1)
        return;
      actions.push({
        id: 'metamorphosisPhaseI',
        type: ACTION_CULT,
        name: 'Metamorphosis, Phase I',
        energy: 0,
        obj: {}
      });
    }
}
