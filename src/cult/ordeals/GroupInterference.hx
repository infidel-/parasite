// group interference ordeal - disrupt group operations
package cult.ordeals;

import game.Game;
import ai.*;
import cult.Ordeal;
import cult.Cult;
import _PlayerAction;

class GroupInterference extends Ordeal
{
  public var powerTypes: Array<String>; // selected power types for this ordeal

  public function new(g: Game)
    {
      super(g);
      init();
      initPost(false);

      // get 3 random free level 2 members
      var free = cult.getFreeMembers(2, true);
      var selected = [];
      var shuf = [];
      for (id in free)
        shuf.push(id);
      shuf.sort(function(a, b) return Std.random(3) - 1);
      for (i in 0...3)
        {
          if (i < shuf.length)
            selected.push(shuf[i]);
        }
      addMembers(selected);

      // pick 3 random power types (including money)
      var allTypes = ['combat', 'media', 'lawfare', 'corporate', 'political', 'money'];
      var shuffled = [];
      for (t in allTypes)
        shuffled.push(t);
      shuffled.sort(function(a, b) return Std.random(3) - 1);
      powerTypes = [];
      for (i in 0...3)
        powerTypes.push(shuffled[i]);

      // set power requirements (10 each for 3 types, 100k if money is picked)
      for (type in powerTypes)
        {
          if (type == 'money')
            power.money = 100000;
          else
            power.inc(type, 10);
        }
    }

// init object before loading/post creation
  public override function init()
    {
      super.init();
      name = 'Group Interference';
      type = ORDEAL_COMMUNAL;
      requiredMembers = 3;
      requiredMemberLevels = 2;
      actions = requiredMembers;
      note = 'Sunder the Group\'s designs to forestall judgment and dim their fervor.';
    }

// called after load or creation
  public override function initPost(onLoad: Bool)
    {
      super.initPost(onLoad);
    }

// handle member death
  public override function onDeath(aidata: AIData)
    {
      fail();
    }

// handle successful completion
  public override function onSuccess()
    {
      // check if ambush is active
      if (game.group.team != null &&
          game.group.team.state == TEAM_AMBUSH)
        {
          game.message({
            text: 'My followers warn someone is waiting for me in ambush.',
            img: 'pedia/team_ambush',
            col: 'alert'
          });
          return;
        }

      // call lowerPriority which will handle team distance or priority
      game.group.lowerPriority(30);

      // show success message
      game.message({
        text: 'The Group\'s designs lie sundered. Their fervor wanes.',
        col: 'cult'
      });
    }

// static method to add groupInterference action to actions array
  public static function initiateAction(game: Game, cult: Cult, actions: Array<_PlayerAction>): Void
    {
      // check if there are 3 free level 2 members
      var free = cult.getFreeMembers(2, true);
      if (free.length < 3)
        return;

      actions.push({
        id: 'groupInterference',
        type: ACTION_CULT,
        name: 'Group Interference',
        energy: 0,
        obj: {}
      });
    }
}
