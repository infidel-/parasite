// defines alcohol junk item
package items;

import l10n.Loc;

import Const;
import _PlayerAction;
import game.Game;
import game._Item;
import ItemInfo;

class Alcohol extends ItemInfo
{
// builds alcohol info
  public function new(game: Game)
    {
      super(game);
      id = 'alcohol';
      name = N('bottle of alcohol');
      type = 'junk';
      unknown = N('glass container of liquid');
    }

// builds alcohol-specific inventory actions
  override public function getInventoryActions(item: _Item): Array<_PlayerAction>
    {
      var actions = super.getInventoryActions(item);
      actions.push({
        id: 'use.' + item.id,
        type: ACTION_INVENTORY,
        name: T('Imbibe {item}', { item: Loc.colored('inventory-item', item) }),
        nameClean: T('Imbibe'),
        energy: 2,
        item: item
      });
      return actions;
    }

// handles alcohol-specific inventory actions
  override public function action(actionID: String, action: _PlayerAction): Null<Bool>
    {
      return switch (actionID)
        {
          case 'use': imbibeAction(action.item);
          default: super.action(actionID, action);
        };
    }

// performs alcohol drinking behavior
  function imbibeAction(item: _Item): Bool
    {
      var host = game.player.host;
      if (host == null)
        return false;

      game.scene.sounds.play('item-' + item.id);
      host.emitSound({
        text: T('*glug*'),
        kind: 'bark',
        radius: 2,
        alertness: 2
      });
      host.log(T('{ai:The} takes a few bold swigs, and the bottle quickly comes to an end.', { ai: host }));
      host.inventory.removeItem(item);

      // apply drunk effect stack and evaluate blackout threshold
      host.onEffect(new effects.Drunk(game, 10));
      var drunkEffect = host.effects.get(EFFECT_DRUNK);

      // trigger blackout when overindulged
      if (drunkEffect.points >= 30)
        {
          host.onEffect(new effects.Paralysis(game, 5));
          host.log(T('{ai:The} staggers, blacks out, and you lose the grip.', { ai: host }));
          host.onDetach('drunk');
          game.playerArea.onDetach();
        }
      return true;
    }
}
