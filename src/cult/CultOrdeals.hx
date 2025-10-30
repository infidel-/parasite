// cult ordeals management class
package cult;

import game.Game;
import _PlayerAction;
import ai.AIData;

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
      
      // check if there are enough free members for upgrade action
      if (freeMembers.length >= 3) // 2 + target
        {
          // elevate the faithful action - opens submenu
          actions.push({
            id: 'upgrade',
            type: ACTION_CULT,
            name: 'Elevate the faithful',
            energy: 0,
            obj: { submenu: 'upgrade' }
          });
        }
      
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

// get upgrade submenu actions
  public function getUpgradeActions(): Array<_PlayerAction>
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
      
      // get free members of level 1
      var freeMembers = cult.getFreeMembers(1);
      for (memberID in freeMembers)
        {
          // find member data
          var member = null;
          for (m in cult.members)
            {
              if (m.id == memberID)
                {
                  member = m;
                  break;
                }
            }
          if (member == null)
            continue;

          // only show level 1 members
          var jobInfo = game.jobs.getJobInfo(member.job);
          if (jobInfo != null &&
              jobInfo.level == 1)
            {
              actions.push({
                id: 'upgrade',
                type: ACTION_CULT,
                name: member.TheName(),
                energy: 0,
                obj: { targetID: memberID }
              });
            }
        }
      
      return actions;
    }

// handle action execution
// menu returns to root after this action
  public function action(action: _PlayerAction)
    {
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
          game.ui.updateWindow();
          return;
        }
      
      // handle upgrade actions
      if (action.id == 'upgrade')
        {
          var targetID = action.obj.targetID;
          var ordeal = new UpgradeFollower(game, targetID);
          
          // add two random free members of level 1 to ordeal (excluding target)
          var freeMembers = cult.getFreeMembers(1);
          var availableMembers = [];
          for (memberID in freeMembers)
            {
              if (memberID != targetID)
                availableMembers.push(memberID);
            }
          
          if (availableMembers.length >= 2)
            {
              // shuffle and take first 2
              var shuffled = [];
              for (id in availableMembers)
                shuffled.push(id);
              shuffled.sort(function(a, b) return Std.random(3) - 1);
              ordeal.addMembers([shuffled[0], shuffled[1]]);
            }
          else if (availableMembers.length >= 1)
            {
              // only one available, use it twice (or handle gracefully)
              ordeal.addMembers([availableMembers[0]]);
            }
          
          list.push(ordeal);
          game.ui.updateWindow();
          return;
        }
      
      return;
    }
}
