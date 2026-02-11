// base info for readable items
package items;

import Const;
import ItemInfo;
import _PlayerAction;
import game.Game;
import game._Item;

class Readable extends ItemInfo
{
// builds readable defaults
  public function new(game: Game)
    {
      super(game);
      type = 'readable';
    }

// builds readable-specific inventory actions
  override public function getInventoryActions(item: _Item): Array<_PlayerAction>
    {
      var actions = super.getInventoryActions(item);
      var itemName = item.getName();
      actions.push({
        id: 'read.' + item.id,
        type: ACTION_INVENTORY,
        name: 'Read ' + Const.col('inventory-item', itemName),
        energy: 10,
        isAgreeable: true,
        item: item
      });
      return actions;
    }

// handles readable-specific inventory actions
  override public function action(actionID: String, action: _PlayerAction): Null<Bool>
    {
      return switch (actionID)
        {
          case 'read': readAction(action.item);
          default: super.action(actionID, action);
        };
    }

// performs reading logic and clue discovery
  function readAction(item: _Item): Bool
    {
      // check if player host is illiterate
      if (game.player.host.hasTrait(TRAIT_ILLITERATE))
        {
          itemFailed("This host cannot read.");
          return false;
        }

      if (item.id == 'book' && !game.area.isHabitat)
        {
          if (game.player.evolutionManager.getLevel(IMP_MICROHABITAT) > 0)
            itemFailed("This action requires intense concentration and time. You can only do it in a habitat.");
          else itemFailed("This action requires intense concentration and time. You cannot do it yet.");
          game.profile.addPediaArticle('msgConcentration');
          return false;
        }

      game.log('You study the contents of the ' + item.name + ' and destroy it.');
      var cnt = 0;
      cnt += (game.timeline.learnClues(item.event, true) ? 1 : 0);
      if (item.id == 'book')
        cnt += (game.timeline.learnClues(item.event, true) ? 1 : 0);
      if (Std.random(100) < 30)
        cnt += (game.timeline.learnSingleClue(item.event, true) ? 1 : 0);
      if (Std.random(100) < 10)
        cnt += (game.timeline.learnSingleClue(item.event, true) ? 1 : 0);

      if (cnt == 0)
        game.player.log('You have not been able to gain any clues.',
          COLOR_TIMELINE);
      game.scene.sounds.play('item-' + item.id);

      game.player.host.inventory.removeItem(item);

      return true;
    }
}
