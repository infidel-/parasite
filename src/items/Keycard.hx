// defines keycard item
package items;

import game.Game;
import ItemInfo;

class Keycard extends ItemInfo
{
// builds keycard info
  public function new(game: Game)
    {
      super(game);
      id = 'keycard';
      name = N('keycard');
      type = 'key';
      unknown = N('flat rectangular object');
    }
}
