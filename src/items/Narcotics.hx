// defines narcotics junk item
package items;

import game.Game;
import ItemInfo;

class Narcotics extends ItemInfo
{
// builds narcotics info
  public function new(game: Game)
    {
      super(game);
      id = 'narcotics';
      name = 'white powder';
      type = 'junk';
      unknown = 'small plastic bag';
    }
}
