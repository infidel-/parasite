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
      name = 'keycard';
      type = 'key';
      unknown = 'flat rectangular object';
    }
}
