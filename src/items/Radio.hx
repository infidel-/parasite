// defines radio item
package items;

import game.Game;
import ItemInfo;

class Radio extends ItemInfo
{
// builds radio info
  public function new(game: Game)
    {
      super(game);
      id = 'radio';
      name = 'police radio';
      type = 'radio';
      unknown = 'small plastic object';
    }
}
