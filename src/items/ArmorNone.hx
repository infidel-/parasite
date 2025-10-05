// defines unarmored clothing placeholder
package items;

import game.Game;
import ItemInfo;

class ArmorNone extends ItemInfo
{
// builds no-armor info
  public function new(game: Game)
    {
      super(game);
      id = 'armorNone';
      name = 'no armor';
      type = 'clothing';
      unknown = 'clothing';
      armor = {
        canAttach: true,
        damage: 0,
        needleDeathChance: 10,
      };
    }
}
