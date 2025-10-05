// defines mobile phone item
package items;

import game.Game;
import ItemInfo;

class MobilePhone extends ItemInfo
{
// builds mobile phone info
  public function new(game: Game)
    {
      super(game);
      id = 'mobilePhone';
      name = 'mobile phone';
      type = 'phone';
      unknown = 'small plastic object';
    }
}
