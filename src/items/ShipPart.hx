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
      unknown = 'strange device';
      isKnown = true;
      names = [
        'engine core',
        'power battery',
        'flow regulator',
        'fuel injector port',
        'power conduit',
        'power relay',
        'sig suppressor',
        'reactor',
        'crystal matrix',
        'wave converter',
        'containment unit',
        'bypass circuit',
        'emitter array',
        'stabilizer'
      ];
    }
}
