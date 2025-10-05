// defines alcohol junk item
package items;

import game.Game;
import ItemInfo;

class Alcohol extends ItemInfo
{
// builds alcohol info
  public function new(game: Game)
    {
      super(game);
      id = 'alcohol';
      name = 'bottle of alcohol';
      type = 'junk';
      unknown = 'glass container of liquid';
    }
}
