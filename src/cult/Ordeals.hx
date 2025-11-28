// cult ordeals management class
package cult;

import game.Game;
import _PlayerAction;
import ai.AIData;
import cult.ordeals.*;

class Ordeals extends _SaveObject
{
  static var _ignoredFields = [ 'cult' ];
  public var game: Game;
  public var list: Array<Ordeal>; // active ordeals
  public var cult(get, never): Cult;
  private function get_cult(): Cult
    {
      return game.cults[0];
    }

  public function new(g: Game)
    {
      game = g;
      list = [];
      init();
      initPost(false);
    }

// init object before loading/post creation
// NOTE: new object fields should init here!
  public function init()
    {
    }

// called after load or creation
  public function initPost(onLoad: Bool)
    {
    }

// handle member death
  public function onDeath(aidata: AIData)
    {
      for (ordeal in list)
        {
          ordeal.onDeath(aidata);
        }
    }

// fail an ordeal
  public function fail(ordeal: Ordeal)
    {
      cult.log('ordeal ' + Const.col('gray', ordeal.customName()) + ' has failed');
      list.remove(ordeal);
    }

// complete an ordeal successfully
  public function success(ordeal: Ordeal)
    {
      cult.log('ordeal ' + Const.col('gray', ordeal.customName()) + ' completed successfully');
      list.remove(ordeal);
    }

// turn processing for ordeals
  public function turn()
    {
      // reset actions counter for all active ordeals
      for (ordeal in list)
        {
          ordeal.actions = 0;
        }
    }

// get initiate ordeal actions
  public function getInitiateOrdealActions(): Array<_PlayerAction>
    {
      var actions: Array<_PlayerAction> = [];
      
      // check for block communal effect
      if (cult.effects.has(CULT_EFFECT_BLOCK_COMMUNAL))
        return actions;
      
      RecruitFollower.initiateAction(cult, actions);
      UpgradeFollower.initiateAction(cult, actions);
      UpgradeFollower2.initiateAction(cult, actions);
      GatherClues.initiateAction(game, cult, actions);
      
      return actions;
    }


// handle action execution
// menu returns to root after this action
  public function action(action: _PlayerAction)
    {
      var ordeal: Ordeal = null;
      var o = action.obj;
      switch (action.id)
        {
          case 'recruit':
            ordeal = new RecruitFollower(game, o.type);
          case 'upgrade':
            ordeal = new UpgradeFollower(game, o.targetID, 1);
          case 'upgrade2':
            ordeal = new UpgradeFollower2(game, o.targetID);
          case 'gatherClues':
            ordeal = new GatherClues(game);
          default:
            return;
        }
      if (ordeal != null)
        {
          list.push(ordeal);
          game.ui.updateWindow();
        }
    }
}
