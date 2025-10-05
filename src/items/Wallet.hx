// defines wallet junk item
package items;

import game.Game;
import ItemInfo;

class Wallet extends ItemInfo
{
// builds wallet info
  public function new(game: Game)
    {
      super(game);
      id = 'wallet';
      name = 'wallet';
      type = 'junk';
      unknown = 'small leather object';
    }
}
