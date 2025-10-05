// defines smartphone item
package items;

import game.Game;
import ItemInfo;

class Smartphone extends ItemInfo
{
// builds smartphone info
  public function new(game: Game)
    {
      super(game);
      id = 'smartphone';
      name = 'smartphone';
      type = 'computer';
      unknown = 'small plastic object';
    }
}
