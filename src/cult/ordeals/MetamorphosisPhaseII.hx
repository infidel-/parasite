// Metamorphosis Phase II communal ordeal
package cult.ordeals;

import cult.Cult;
import cult.Ordeal;
import cult.RivalCult;
import cult.base.CultBase;
import game.Game;
import _PlayerAction;
import _PlayerActionType;

class MetamorphosisPhaseII extends Ordeal
{
  public function new(g: Game)
    {
      super(g);
      init();
      initPost(false);
      var free = cult.getFreeMembers(3, true);
      if (free.length > 0)
        addMembers([ free[0] ]);
    }

// init ordeal fields
  public override function init()
    {
      super.init();
      name = N('Metamorphosis, Phase II');
      type = ORDEAL_COMMUNAL;
      requiredMembers = 1;
      requiredMemberLevels = 3;
      actions = 0;
      note = N('Perform the ritual in the current habitat.');
    }

// adds ritual completion action
  public override function getActions(): Array<_PlayerAction>
    {
      var actions = [];
      actions.push({
        id: 'performMetamorphosis',
        type: ACTION_CULT,
        name: T('Perform metamorphosis ritual'),
        energy: 0,
        f: function() {
          // the base grows in a habitat: refuse anywhere else and keep the ordeal, since
          // success() removes it whatever onSuccess does
          if (game.location != LOCATION_AREA ||
              !game.area.isHabitat)
            {
              game.actionFailed(T('The ritual must finish in a habitat.'));
              return;
            }
          success();
          game.ui.closeWindow();
        }
      });
      actions.push({
        id: 'annul',
        type: ACTION_CULT,
        name: T('Annul') + ' ' + Const.smallgray(T('(results in failure)')),
        energy: 0,
        f: function() {
          fail();
          game.ui.cult.setMenuState(STATE_ROOT);
          game.ui.updateWindow();
        }
      });
      return actions;
    }

// creates the living base
  public override function onSuccess()
    {
      cult.level = 2;
      cult.base = new CultBase(game, game.area.id,
        game.playerArea.x, game.playerArea.y);
      RivalCult.generate(game, RIVAL_COMBAT);
      RivalCult.generate(game, RIVAL_NON_COMBAT);
      game.profile.addPediaArticle('cultBase');
      game.message({
        text: T('Cor Nefandum opens. Cultus Carnis enters its second form.'),
        col: 'cult'
      });
    }

// adds initiate action when Phase I is complete and player is in habitat
  public static function initiateAction(cult: Cult, actions: Array<_PlayerAction>)
    {
      if (cult.level != 1 ||
          !cult.metamorphosisPhaseIComplete ||
          cult.base != null)
        return;
      if (cult.game.location != LOCATION_AREA ||
          cult.game.area == null ||
          !cult.game.area.isHabitat)
        return;
      actions.push({
        id: 'metamorphosisPhaseII',
        type: ACTION_CULT,
        name: T('Metamorphosis, Phase II'),
        energy: 0,
        obj: {}
      });
    }
}
