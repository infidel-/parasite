// defines cigarettes junk item
package items;

import game.Game;
import ItemInfo;

class Cigarettes extends ItemInfo
{
// builds cigarettes info
  public function new(game: Game)
    {
      super(game);
      id = 'cigarettes';
      name = 'pack of cigarettes';
      type = 'junk';
      unknown = 'small container';
    }
}
