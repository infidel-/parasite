// defines money junk item
package items;

import game.Game;
import ItemInfo;
import game._Item;

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
          id: 'throwMoney.' + item.id,
          type: ACTION_INVENTORY,
          item: item,
          name: 'Throw money',
          energy: 5,
          isAgreeable: true,
        });
    }
}
