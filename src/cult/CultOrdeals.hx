// cult ordeals management class
package cult;

import game.Game;
import _PlayerAction;

class CultOrdeals extends _SaveObject
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

// get initiate ordeal actions
  public function getInitiateOrdealActions(): Array<_PlayerAction>
    {
      var actions: Array<_PlayerAction> = [];
      
      // check if there are enough free members for recruit action
      var freeMembers = cult.getFreeMembers(1);
      if (freeMembers.length >= 1)
        {
          // seek the pure action - opens submenu
          actions.push({
            id: 'recruit',
            type: ACTION_CULT,
            name: 'Seek the pure',
            energy: 0,
            obj: { submenu: 'recruit' }
          });
        }
      
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

// get recruit submenu actions
  public function getRecruitActions(): Array<_PlayerAction>
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
      
      // power type options
      actions.push({
        id: 'recruit',
        type: ACTION_CULT,
        name: 'Combat',
        energy: 0,
        obj: { type: 'combat' }
      });
      
      actions.push({
        id: 'recruit',
        type: ACTION_CULT,
        name: 'Media',
        energy: 0,
        obj: { type: 'media' }
      });
      
      actions.push({
        id: 'recruit',
        type: ACTION_CULT,
        name: 'Lawfare',
        energy: 0,
        obj: { type: 'lawfare' }
      });
      
      actions.push({
        id: 'recruit',
        type: ACTION_CULT,
        name: 'Corporate',
        energy: 0,
        obj: { type: 'corporate' }
      });
      
      actions.push({
        id: 'recruit',
        type: ACTION_CULT,
        name: 'Political',
        energy: 0,
        obj: { type: 'political' }
      });
      
      return actions;
    }

// handle action execution
// menu returns to root after this action
  public function action(action: _PlayerAction)
    {
      game.log('CultOrdeals action: ' + action.name);
      
      // handle recruit actions
      if (action.id == 'recruit')
        {
          var ordeal = new RecruitFollower(game, action.obj.type);
          
          // add random free member to ordeal
          var freeMembers = cult.getFreeMembers(1);
          if (freeMembers.length > 0)
            {
              var randomMemberID = freeMembers[Std.random(freeMembers.length)];
              ordeal.addMembers([randomMemberID]);
            }
          
          list.push(ordeal);
          game.log('Created RecruitFollower ordeal for followerType: ' + action.obj.type);
          return;
        }
      
      if (action.obj != null)
        {
          game.log('Action object: ' + Std.string(action.obj));
        }
      
      return;
    }
}
