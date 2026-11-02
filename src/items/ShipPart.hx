// defines ship part scenario item
package items;

import game.Game;
import ItemInfo;

class ShipPart extends ItemInfo
{
// builds ship part info
  public function new(game: Game)
    {
      super(game);
      id = 'shipPart';
      type = 'scenario';
      unknown = N('strange device');
      isKnown = true;
      names = [
        N('engine core'),
        N('power battery'),
        N('flow regulator'),
        N('fuel injector port'),
        N('power conduit'),
        N('power relay'),
        N('sig suppressor'),
        N('reactor'),
        N('crystal matrix'),
        N('wave converter'),
        N('containment unit'),
        N('bypass circuit'),
        N('emitter array'),
        N('stabilizer')
      ];
    }
}
