// defines laptop item
package items;

import game.Game;
import ItemInfo;

class Laptop extends ItemInfo
{
// builds laptop info
  public function new(game: Game)
    {
      super(game);
      id = 'laptop';
      name = 'laptop';
      type = 'computer';
      unknown = 'plastic rectangular object';
    }
}
