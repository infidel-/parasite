// base info for weapon items
package items;

import l10n.Loc;

import Const;
import ItemInfo;
import _PlayerAction;
import ai.AI;
import AttackTarget;
import game.Game;
import game._Item;

class Weapon extends ItemInfo
{
// builds weapon defaults
  public function new(game: Game)
    {
      super(game);
      type = 'weapon';
    }

// builds weapon-specific inventory actions
  override public function getInventoryActions(item: _Item): Array<_PlayerAction>
    {
      var actions = super.getInventoryActions(item);
      actions.push({
        id: 'active.' + item.id,
        type: ACTION_INVENTORY,
        name: T('Mark {item} as active', { item: Loc.colored('inventory-item', item) }),
        nameClean: T('Mark as active'),
        energy: 0,
        item: item
      });
      return actions;
    }

// handles weapon-specific inventory actions
  override public function action(actionID: String, action: _PlayerAction): Null<Bool>
    {
      return switch (actionID)
        {
          case 'active': activeAction(action.item);
          default: super.action(actionID, action);
        };
    }

// marks this weapon as the active choice; virtual (returns false so no energy/turn is spent)
  function activeAction(item: _Item): Bool
    {
      game.log(T('You will now attack with {item:the}.', { item: Loc.thing(item.name) }));
      game.player.host.inventory.weaponID = item.id;
      return false;
    }

// post-hit combat hook for weapon-specific side effects
  public function logicAttackPost(ai: AI, target: AttackTarget, isAttackerPlayer: Bool): Void
    {
    }
}
