// Metamorphosis Phase II communal ordeal
package cult.ordeals;

import cult.Cult;
import cult.Ordeal;
import cult.RivalCult;
import cult.base.CultBase;
import const.CultConst;
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
      name = 'Metamorphosis, Phase II';
      type = ORDEAL_COMMUNAL;
      requiredMembers = 1;
      requiredMemberLevels = 3;
      actions = 0;
      note = 'Perform the ritual in the current habitat.';
    }

// adds ritual completion action
  public override function getActions(): Array<_PlayerAction>
    {
      var actions = [];
      actions.push({
        id: 'performMetamorphosis',
        type: ACTION_CULT,
        name: 'Perform metamorphosis ritual',
        energy: 0,
        f: function() {
          success();
          game.ui.closeWindow();
        }
      });
      actions.push({
        id: 'annul',
        type: ACTION_CULT,
        name: 'Annul ' + Const.smallgray('(results in failure)'),
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
      if (game.location != LOCATION_AREA ||
          game.area == null ||
          !game.area.isHabitat)
        {
          game.actionFailed('The ritual must finish in a habitat.');
          return;
        }
      cult.level = 2;
      cult.base = new CultBase(game, game.area.id,
        game.playerArea.x, game.playerArea.y);
      game.cults.push(createRivalCult(game,
        CultConst.randomRivalID(RIVAL_COMBAT)));
      game.cults.push(createRivalCult(game,
        CultConst.randomRivalID(RIVAL_NON_COMBAT)));
      game.profile.addPediaArticle('cultBase');
      game.message({
        text: 'Cor Nefandum opens. Cultus Carnis enters its second form.',
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
        name: 'Metamorphosis, Phase II',
        energy: 0,
        obj: {}
      });
    }

// creates a strategic rival as a real cult
  static function createRivalCult(game: Game, cultInfoID: String): RivalCult
    {
      var info = CultConst.info(cultInfoID);
      var rival = new RivalCult(game);
      rival.name = info.name;
      rival.isPlayer = false;
      rival.state = CULT_STATE_ACTIVE;
      rival.level = 2;
      rival.rivalInfoID = info.id;
      rival.rivalTemplate = info.memberTemplate;
      rival.rivalTactic = info.tactic;
      if (info.tactic == RIVAL_COMBAT)
        rival.power.combat = 8;
      else
        rival.power.media = 4 + Std.random(3);
      for (type in rivalMemberTypes(info.memberTemplate, info.tactic))
        addRivalMember(rival, type);
      rival.recalc();
      return rival;
    }

// returns starting roster types for one rival cult
  static function rivalMemberTypes(template: String,
      tactic: _RivalCultTactic): Array<String>
    {
      if (tactic == RIVAL_COMBAT)
        return [
          'security',
          'thug',
          'thug',
          'security',
          'soldier',
          'thug'
        ];
      if (template == 'occult')
        return [
          'scientist',
          'civilian',
          'thug',
          'scientist',
          'security',
          'civilian'
        ];
      return [
        'civilian',
        'scientist',
        'thug',
        'security',
        'civilian',
        'scientist'
      ];
    }

// creates one roster member for a rival cult
  static function addRivalMember(rival: RivalCult, type: String)
    {
      var ai = rival.game.createAI(type, 0, 0);
      ai.setCult(rival);
      rival.members.push(ai.cloneData());
    }
}
