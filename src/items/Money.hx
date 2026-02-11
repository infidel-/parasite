// defines money junk item
package items;

import Const;
import _PlayerAction;
import game.Game;
import game._Item;
import ItemInfo;

class Money extends ItemInfo
{
// builds money info
  public function new(game: Game)
    {
      super(game);
      id = 'money';
      name = 'wad of money';
      type = 'junk';
      unknown = 'pack of thin objects';
    }

// adds throw money action when item is known
  public override function updateActionList(item: _Item): Void
    {
      if (game.player.knowsItem(item.id))
        game.ui.hud.addAction({
          id: 'use.' + item.id,
          type: ACTION_INVENTORY,
          item: item,
          name: 'Throw money',
          energy: 5,
          isAgreeable: true,
        });
    }

// handles money-specific inventory actions
  override public function action(actionID: String, action: _PlayerAction): Null<Bool>
    {
      return switch (actionID)
        {
          case 'use': throwMoneyAction(action.item);
          default: super.action(actionID, action);
        };
    }

// performs money throwing crowd control
  function throwMoneyAction(item: _Item): Bool
    {
      var range = 3;
      var time = 3;
      var targets = game.area.getAIinRadius(
        game.playerArea.x, game.playerArea.y,
        range, false);

      game.log('Your host throws money around.');
      game.scene.sounds.play('item-money');
      game.player.host.inventory.removeItem(item);

      var xo = game.playerArea.x;
      var yo = game.playerArea.y;
      for (yy in yo - range...yo + range)
        for (xx in xo - range...xo + range)
          {
            if (!game.area.isWalkable(xx, yy))
              continue;

            if (Const.distanceSquared(xo, yo, xx, yy) > range * range)
              continue;

            new particles.ParticleMoney(game.scene,
              { x: xx, y: yy });
          }

      for (ai in targets)
        {
          if (ai == game.player.host ||
              !ai.isHuman)
            continue;

          if (ai.state == AI_STATE_IDLE)
            {
              ai.alertness = 100;
              ai.setState(AI_STATE_ALERT, REASON_PARASITE);
            }

          ai.onEffect(new effects.Paralysis(game, time));
        }
      game.scene.updateCamera();

      return true;
    }
}
