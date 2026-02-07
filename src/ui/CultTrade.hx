// cult trade menu helper

package ui;

import game.Game;

class CultTrade
{
  var game: Game;
  var cultWindow: Cult;
  var selectedResource: String;

  public function new(g: Game, cultWindow: Cult)
    {
      game = g;
      this.cultWindow = cultWindow;
    }

// builds trade menu for money to resource
  public function showTrade()
    {
      // back button
      cultWindow.addPlayerAction({
        id: 'back',
        type: ACTION_CULT,
        name: 'Back',
        energy: 0,
        f: function() {
          cultWindow.setMenuState(STATE_ROOT);
          cultWindow.updateActions();
        }
      });

      var cult = game.cults[0];
      var cost = cult.getTradeCost();

      if (cult.resources.money < cost)
        return;

      // trade actions for each power type
      for (i in 0..._CultPower.names.length)
        {
          var power = _CultPower.names[i];
          var powerType = power; // capture the power type for the closure
          cultWindow.addPlayerAction({
            id: 'trade.' + power,
            type: ACTION_CULT,
            name: 'To ' + Const.col('cult-power', power) +
              ' resource (' +
              Const.col('cult-power', cost) + Icon.money + ')',
            energy: 0,
            f: function() {
              cult.trade(powerType);
              cultWindow.update();
            }
          });
        }
    }

// builds resource selection menu for trades
  public function showSelectResource()
    {
      // back button
      cultWindow.addPlayerAction({
        id: 'back',
        type: ACTION_CULT,
        name: 'Back',
        energy: 0,
        f: function() {
          cultWindow.setMenuState(STATE_ROOT);
          cultWindow.updateActions();
        }
      });

      var cult = game.cults[0];
      var cost = cult.getTradeResourceCost();

      // resource selection actions
      for (i in 0..._CultPower.names.length)
        {
          var resource = _CultPower.names[i];
          var resourceType = resource; // capture for closure
          var amount = cult.resources.get(resource);
          if (amount >= cost)
            cultWindow.addPlayerAction({
              id: 'select.' + resource,
              type: ACTION_CULT,
              name: Const.col('cult-power', _CultPower.namesCap[i]) +
                ' (' + amount + ')',
              energy: 0,
              f: function() {
                selectedResource = resourceType;
                cultWindow.setMenuState(STATE_TRADE_RESOURCE);
                cultWindow.updateActions();
              }
            });
        }
    }

// builds trade menu for resource to resource
  public function showTradeResource()
    {
      // back button
      cultWindow.addPlayerAction({
        id: 'back',
        type: ACTION_CULT,
        name: 'Back',
        energy: 0,
        f: function() {
          cultWindow.setMenuState(STATE_SELECT_RESOURCE);
          cultWindow.updateActions();
        }
      });

      var cult = game.cults[0];
      var cost = cult.getTradeResourceCost();
      var from = selectedResource;
      if (cult.resources.get(from) < cost)
        return;

      // trade actions for each power type (excluding the source resource)
      for (i in 0..._CultPower.names.length)
        {
          var to = _CultPower.names[i];
          var toType = to; // capture for closure

          if (to == from)
            continue;
          cultWindow.addPlayerAction({
            id: 'trade.' + from + '.' + to,
            type: ACTION_CULT,
            name: 'To ' + Const.col('cult-power', _CultPower.names[i]) +
              ' resource (' + cost + ' ' +
              Const.col('cult-power', from) + ')',
            energy: 0,
            f: function() {
              cult.tradeResource(from, toType);
              cultWindow.update();
            }
          });
        }
    }
}
