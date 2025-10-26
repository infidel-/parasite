// cult ordeals management class
package cult;

import game.Game;
import _PlayerAction;
import _PlayerActionType;

class CultOrdeals extends _SaveObject
{
  public var game: Game;
  public var list: Array<Ordeal>; // active ordeals

  public function new(g: Game)
    {
      game = g;
      list = [];
      init();
      initPost(false);
    }

// init object before loading/post creation
  public function init()
    {
    }

// called after load or creation
  public function initPost(onLoad: Bool)
    {
    }

// get initiate ordeal actions
  public function getInitiateOrdealActions(): Array<_PlayerAction>
    {
      var actions = [];
      
      // test action 1
      actions.push({
        id: 'testOrdeal1',
        type: ACTION_CULT,
        name: 'Test Ordeal 1',
        energy: 0,
        obj: { ordealType: 'test1', description: 'First test ordeal' }
      });
      
      // test action 2
      actions.push({
        id: 'testOrdeal2',
        type: ACTION_CULT,
        name: 'Test Ordeal 2',
        energy: 0,
        obj: { ordealType: 'test2', description: 'Second test ordeal' }
      });
      
      // test action 3
      actions.push({
        id: 'testOrdeal3',
        type: ACTION_CULT,
        name: 'Test Ordeal 3',
        energy: 0,
        obj: { ordealType: 'test3', description: 'Third test ordeal' }
      });
      
      return actions;
    }

// handle action execution
// returns true if action should close window
  public function action(action: _PlayerAction): Bool
    {
      game.log('CultOrdeals action: ' + action.name);
      if (action.obj != null)
        {
          game.log('Action object: ' + Std.string(action.obj));
        }
      return false;
    }
}
