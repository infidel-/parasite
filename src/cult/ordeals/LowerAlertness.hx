// lower alertness ordeal - placate the realm
package cult.ordeals;

import game.Game;
import ai.*;
import cult.Ordeal;
import cult.Cult;
import _PlayerAction;

class LowerAlertness extends Ordeal
{
  public var powerTypes: Array<String>; // selected power types for this ordeal

  public function new(g: Game)
    {
      super(g);
      init();
      initPost(false);

      // pick 2 random free level 2 members
      var free = cult.getFreeMembers(2, true);
      var selected = [];
      var shuf = [];
      for (id in free)
        shuf.push(id);
      shuf.sort(function(a, b) return Std.random(3) - 1);
      for (i in 0...2)
        {
          if (i < shuf.length)
            selected.push(shuf[i]);
        }
      addMembers(selected);

      // pick 2 random power types (including money)
      var allTypes = ['media', 'lawfare', 'corporate', 'political', 'money'];
      var shuffled = [];
      for (t in allTypes)
        shuffled.push(t);
      shuffled.sort(function(a, b) return Std.random(3) - 1);
      powerTypes = [];
      for (i in 0...2)
        powerTypes.push(shuffled[i]);

      // set power requirements (5 each for 2 types, 100k if money is picked)
      for (type in powerTypes)
        {
          if (type == 'money')
            power.money = 100000;
          else
            power.inc(type, 5);
        }
    }

// init object before loading/post creation
  public override function init()
    {
      super.init();
      name = 'Placate the realm';
      type = ORDEAL_COMMUNAL;
      requiredMembers = 2;
      requiredMemberLevels = 2;
      actions = requiredMembers;
      note = 'Two seasoned devotees will still the tumult in the realm.';
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
      // lower alertness in all areas of the region
      for (area in game.region.iterator())
        {
          if (area.alertness > 0)
            area.alertness -= Const.roll(10, 30);
        }

      // update region view if currently in region
      if (game.location == LOCATION_REGION)
        game.scene.region.update();

      // show success message
      game.message({
        text: 'The tumult wanes.',
        col: 'cult'
      });
    }

// static method to add lowerAlertness action to actions array
  public static function initiateAction(game: Game, cult: Cult, actions: Array<_PlayerAction>): Void
    {
      // check if there are 2 free level 2 members
      var free = cult.getFreeMembers(2, true);
      if (free.length < 2)
        return;

      actions.push({
        id: 'lowerAlertness',
        type: ACTION_CULT,
        name: 'Placate the realm',
        energy: 0,
        obj: {}
      });
    }
}
