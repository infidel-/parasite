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
      name = N('Metamorphosis, Phase I');
      type = ORDEAL_COMMUNAL;
      requiredMembers = 1;
      requiredMemberLevels = 3;
      actions = requiredMembers;
      note = N('A perfected follower seeks the most forbidden of knowledges.');
    }

// unlocks Phase II
  public override function onSuccess()
    {
      complete(cult);
    }

// Phase I is done: the book goes to the cult and Phase II opens
  static function complete(cult: Cult)
    {
      var game = cult.game;
      cult.metamorphosisPhaseIComplete = true;
      if (isHeld(game))
        {
          game.player.host.inventory.remove('necronomicon');
          game.log(T('Your followers take the Necronomicon away to study it.'));
        }
      game.logsg(T('Metamorphosis Phase II is now possible.'));
    }

// does the player's host carry the Necronomicon?
  public static function isHeld(game: Game): Bool
    {
      return game.player.state == PLR_STATE_HOST &&
        game.player.host.inventory.has('necronomicon');
    }

// the book held at the moment Phase I would open completes it at once, no ordeal needed. Skipped
// while the ordeal runs: its mission completes on leaving the library instead
  public static function checkHeld(cult: Cult)
    {
      if (!cult.isPlayer ||
          cult.level != 1 ||
          cult.metamorphosisPhaseIComplete ||
          cult.countMembers(3) != 1 ||
          !isHeld(cult.game))
        return;
      for (o in cult.ordeals.list)
        if (Std.isOfType(o, MetamorphosisPhaseI))
          return;
      complete(cult);
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
        name: T('Metamorphosis, Phase I'),
        energy: 0,
        obj: {}
      });
    }
}
