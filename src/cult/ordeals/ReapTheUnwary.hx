// Reap the Unwary communal ordeal
package cult.ordeals;

import cult.Cult;
import cult.Ordeal;
import _PlayerAction;

class ReapTheUnwary extends Ordeal
{
  public var powerTypes: Array<String>;

// returns the initiate-menu price hint for this ordeal
  public static function priceHint(): String
    {
      return Const.smallgray(' (') +
        T('2x: {power} PWR or {money}', {
          power: Const.col('cult-power', 2),
          money: Const.col('cult-power', '100k') + Icon.money,
        }) +
        Const.smallgray(')');
    }

  public function new(g: game.Game)
    {
      super(g);
      init();
      initPost(false);
      addRandomMembers({
        level: 1,
        amount: 2,
        onlyGivenLevel: true
      });
      powerTypes = randomPowerTypes();
      for (type in powerTypes)
        {
          if (type == 'money')
            power.money = 100000;
          else
            power.set(type, 2);
        }
    }

// init ordeal fields
  public override function init()
    {
      super.init();
      name = N('Reap the Unwary');
      type = ORDEAL_COMMUNAL;
      requiredMembers = 2;
      requiredMemberLevels = 1;
      actions = requiredMembers;
      note = N('The faithful gather bodies for Cadaverum.');
      powerTypes = [];
    }

// add bodies on success
  public override function onSuccess()
    {
      var lost = cult.base.addBodies(4);
      if (lost > 0)
        cult.log(T('{cult} reaps {n, plural, one{# body} other{# bodies}}, losing {lost} to overflow.', {
          cult: cult,
          n: 4 - lost,
          lost: lost,
        }));
      else
        cult.log(T('{cult} reaps {n, plural, one{# body} other{# bodies}}.', {
          cult: cult,
          n: 4,
        }));
    }

// adds initiate action
  public static function initiateAction(cult: Cult, actions: Array<_PlayerAction>)
    {
      if (cult.base == null ||
          !cult.base.hasWorkingOrgan(BODY_STORAGE))
        return;
      var free = cult.getFreeMembers(1, true);
      if (free.length < 2)
        return;
      actions.push({
        id: 'reapTheUnwary',
        type: ACTION_CULT,
        name: T('Reap the Unwary') + priceHint(),
        energy: 0,
        obj: {}
      });
    }

// picks two random cost variants
  function randomPowerTypes(): Array<String>
    {
      var types = ['media', 'lawfare', 'corporate', 'political', 'money'];
      types.sort(function(a, b) return Std.random(3) - 1);
      return [ types[0], types[1] ];
    }
}
