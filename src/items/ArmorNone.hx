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
      name = N('no armor');
      type = 'clothing';
      unknown = N('clothing');
      armor = {
        canAttach: true,
        damage: 0,
        needleDeathChance: 10,
      };
    }
}
