// defines nutrients consumable item
package items;

import game.Game;
import ItemInfo;

class Nutrients extends ItemInfo
{
// builds nutrients info
  public function new(game: Game)
    {
      super(game);
      id = 'nutrients';
      name = 'nutrients';
      type = 'nutrients';
      unknown = 'uneven dark-red object';
      isKnown = true;
    }
}
